class RevertBlockJob < ApplicationJob
  def perform(local_tip_block = nil)
    local_tip_block =
      case local_tip_block
      when nil
        Block.recent.first
      when Integer
        Block.find(local_tip_block)
      else
        local_tip_block
      end

    ApplicationRecord.transaction do
      benchmark :revert_dao_contract_related_operations, local_tip_block
      benchmark :revert_mining_info, local_tip_block

      udt_type_hashes =
        ApplicationRecord.benchmark "pluck type_hash" do
          local_tip_block.cell_outputs.
            udt.pluck(:type_hash).
            uniq.concat(local_tip_block.cell_outputs.m_nft_token.pluck(:type_hash).uniq)
        end
      benchmark :recalculate_udt_transactions_count, local_tip_block
      benchmark :decrease_records_count, local_tip_block
      benchmark :update_address_balance_and_ckb_transactions_count, local_tip_block

      ApplicationRecord.benchmark "invalid! block" do
        local_tip_block.invalid!
      end

      benchmark :recalculate_udt_accounts, udt_type_hashes, local_tip_block
      benchmark :revert_block_rewards, local_tip_block
      ForkedEvent.create!(block_number: local_tip_block.number, epoch_number: local_tip_block.epoch,
                          block_timestamp: local_tip_block.timestamp)
      ApplicationRecord.benchmark "BlockStatisticGenerator" do
        Charts::BlockStatisticGenerator.new(local_tip_block.number).call
      end
      local_tip_block
    end
  end

  def update_address_balance_and_ckb_transactions_count(local_tip_block)
    select_fields = [
      "address_id",
      "COUNT(*) AS cells_count",
      "SUM(capacity) AS total_capacity",
      "SUM(CASE WHEN type_hash IS NOT NULL OR data_hash IS NOT NULL THEN capacity ELSE 0 END) AS balance_occupied",
    ]
    output_addrs =
      local_tip_block.cell_outputs.live.select(select_fields.join(", ")).group(:address_id)
    input_addrs =
      CellOutput.where(consumed_block_timestamp: local_tip_block.timestamp).select(select_fields.join(", ")).group(:address_id)
    out_hash = output_addrs.each_with_object({}) do |row, h|
      h[row.address_id] = {
        cells_count: row.cells_count.to_i,
        total_capacity: row.total_capacity.to_i,
        balance_occupied: row.balance_occupied.to_i,
      }
    end

    in_hash = input_addrs.each_with_object({}) do |row, h|
      h[row.address_id] = {
        cells_count: row.cells_count.to_i,
        total_capacity: row.total_capacity.to_i,
        balance_occupied: row.balance_occupied.to_i,
      }
    end

    # Merge keys
    all_ids = in_hash.keys | out_hash.keys

    # 计算差值
    address_balance_diff = all_ids.each_with_object({}) do |addr_id, h|
      input  = in_hash[addr_id]  || { cells_count: 0, total_capacity: 0, balance_occupied: 0 }
      output = out_hash[addr_id] || { cells_count: 0, total_capacity: 0, balance_occupied: 0 }

      h[addr_id] = {
        cells_count: input[:cells_count] - output[:cells_count],
        total_capacity: input[:total_capacity] - output[:total_capacity],
        balance_occupied: input[:balance_occupied] - output[:balance_occupied],
      }
    end
    # Preload dao transaction counts for all addresses in one query
    dao_tx_counts = DaoEvent.processed.
      where(block_id: local_tip_block.id, address_id: all_ids).
      group(:address_id).
      distinct.
      count(:ckb_transaction_id)
    tx_count_diffs = AccountBook.tx_committed.
      where(block_number: local_tip_block.number, address_id: all_ids).
      group(:address_id).
      count

    changes =
      address_balance_diff.map do |address_id, changes|
        tx_count_diff = tx_count_diffs[address_id] || 0
        dao_tx_count_diff = dao_tx_counts[address_id] || 0
        { address_id: address_id }.merge(changes).merge({ ckb_transactions_count: tx_count_diff, dao_transactions_count: dao_tx_count_diff })
      end

    changes.each do |change|
      addr = Address.find_by_id(change[:address_id])
      if addr
        addr.update!(
          live_cells_count: addr.live_cells_count + change[:cells_count],
          ckb_transactions_count: addr.ckb_transactions_count - change[:ckb_transactions_count],
          balance: addr.balance + change[:total_capacity],
          balance_occupied: addr.balance_occupied + change[:balance_occupied],
          dao_transactions_count: addr.dao_transactions_count - change[:dao_transactions_count]
        )
      end
    end
  end

  def recalculate_udt_transactions_count(local_tip_block)
    udt_ids = local_tip_block.ckb_transactions.map(&:contained_udt_ids).flatten
    udt_counts = udt_ids.each_with_object(Hash.new(0)) { |udt_id, counts| counts[udt_id] += 1 }
    udt_counts_value =
      udt_counts.map do |udt_id, count|
        udt = Udt.find(udt_id)
        {
          id: udt_id,
          ckb_transactions_count: udt.ckb_transactions_count - count,
          created_at: udt.created_at,
          updated_at: Time.current,
        }
      end

    Udt.upsert_all(udt_counts_value) if udt_counts_value.present?
  end

  def recalculate_udt_accounts(udt_type_hashes, local_tip_block)
    return if udt_type_hashes.blank?

    local_tip_block.contained_addresses.find_each do |address|
      udt_type_hashes.each do |type_hash|
        udt_account = address.udt_accounts.find_by(type_hash:)
        next if udt_account.blank?

        case udt_account.udt_type
        when "sudt"
          amount = address.cell_outputs.live.udt.where(type_hash:).sum(:udt_amount)
          udt_account.update!(amount:)
        when "xudt", "omiga_inscription", "xudt_compatible"
          amount = address.cell_outputs.live.where(cell_type: udt_account.udt_type).where(type_hash:).sum(:udt_amount)
          udt_account.update!(amount:)
        when "m_nft_token", "nrc_721_token", "spore_cell", "did_cell"
          udt_account.destroy
        end
      end
    end
  end

  def revert_mining_info(local_tip_block)
    local_tip_block.mining_infos.first.reverted!
    miner_address = local_tip_block.miner_address
    miner_address.decrement!(:mined_blocks_count)
  end

  def revert_dao_contract_related_operations(local_tip_block)
    dao_events = DaoEvent.where(block: local_tip_block).processed
    dao_transactions_count = local_tip_block.ckb_transactions.where("tags @> array[?]::varchar[]", ["dao"]).count
    dao_contract = DaoContract.default_contract

    withdraw_transactions_count, withdraw_total_deposit = revert_withdraw_from_dao(dao_events)
    claimed_compensation = revert_issue_interest(dao_events)
    deposit_transactions_count, deposit_total_deposit = revert_deposit_to_dao(dao_events)

    dao_events.update_all(status: "reverted")
    dao_contract.update!(deposit_transactions_count: dao_contract.deposit_transactions_count - deposit_transactions_count,
                         withdraw_transactions_count: dao_contract.withdraw_transactions_count - withdraw_transactions_count,
                         total_deposit: dao_contract.total_deposit + withdraw_total_deposit - deposit_total_deposit,
                         claimed_compensation: dao_contract.claimed_compensation - claimed_compensation,
                         ckb_transactions_count: dao_contract.ckb_transactions_count - dao_transactions_count,
                         depositors_count: DaoEvent.depositor.count)
  end

  def revert_issue_interest(dao_events)
    issue_interest_dao_events = dao_events.issue_interest
    claimed_compensation = 0
    address_attrs = {}
    issue_interest_dao_events.each do |event|
      claimed_compensation += event.value

      address = event.address
      address_attrs[address.id] ||= {
        id: address.id,
        interest: address.interest,
      }
      address_attrs[address.id][:interest] -= event.value
    end
    upsert_data = address_attrs.values
    Address.upsert_all(upsert_data, unique_by: :id) if upsert_data.present?
    claimed_compensation
  end

  def revert_withdraw_from_dao(dao_events)
    withdraw_from_dao_events = dao_events.includes(:address).withdraw_from_dao

    ids = withdraw_from_dao_events.pluck(:ckb_transaction_id)
    DaoEvent.processed.where(consumed_transaction_id: ids).update_all(consumed_transaction_id: nil)

    redundant_total_deposit = 0
    address_attrs = {}
    withdraw_from_dao_events.each do |event|
      redundant_total_deposit += event.value

      address = event.address
      address_attrs[address.id] ||= {
        id: address.id,
        dao_deposit: address.dao_deposit,
        is_depositor: address.is_depositor,
      }
      address_attrs[address.id][:dao_deposit] += event.value
      address_attrs[address.id][:is_depositor] = true
    end

    upsert_data = address_attrs.values
    Address.upsert_all(upsert_data, unique_by: :id) if upsert_data.present?

    [withdraw_from_dao_events.size, redundant_total_deposit]
  end

  def revert_deposit_to_dao(dao_events)
    deposit_to_dao_events = dao_events.deposit_to_dao
    redundant_total_deposit = 0
    address_attrs = {}

    deposit_to_dao_events.each do |event|
      redundant_total_deposit += event.value

      address = event.address
      address_attrs[address.id] ||= {
        id: address.id,
        dao_deposit: address.dao_deposit,
      }
      address_attrs[address.id][:dao_deposit] -= event.value
    end

    upsert_data = address_attrs.values
    address_ids = address_attrs.values.pluck(:id)
    Address.upsert_all(upsert_data, unique_by: :id) if upsert_data.present?
    Address.where(id: address_ids, dao_deposit: 0).update_all(is_depositor: false)

    [deposit_to_dao_events.size, redundant_total_deposit]
  end

  def revert_block_rewards(local_tip_block)
    target_block = local_tip_block.target_block
    target_block_number = local_tip_block.target_block_number
    return if target_block_number < 1 || target_block.blank?

    revert_reward_status(target_block)
    revert_received_tx_fee(target_block)
  end

  def revert_reward_status(target_block)
    target_block.update!(reward_status: "pending")
    target_block.update!(received_tx_fee_status: "pending")
  end

  def revert_received_tx_fee(target_block)
    target_block.update!(received_tx_fee: 0)
  end

  def decrease_records_count(local_tip_block)
    block_counter = TableRecordCount.find_or_initialize_by(table_name: "blocks")
    block_counter.decrement!(:count)
    ckb_transaction_counter = TableRecordCount.find_or_initialize_by(table_name: "ckb_transactions")
    normal_transactions = local_tip_block.ckb_transactions.normal
    ckb_transaction_counter.decrement!(:count, normal_transactions.count) if normal_transactions.present?
  end
end
