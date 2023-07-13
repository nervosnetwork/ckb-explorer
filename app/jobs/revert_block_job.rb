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
      CkbTransaction.tx_pending.
        where(tx_hash: local_tip_block.ckb_transactions.pluck(:tx_hash)).update_all(tx_status: "pending")
      benchmark :revert_dao_contract_related_operations, local_tip_block
      benchmark :revert_mining_info, local_tip_block

      udt_type_hashes =
        ApplicationRecord.benchmark "pluck type_hash" do
          local_tip_block.cell_outputs.
            udt.pluck(:type_hash).
            uniq.concat(local_tip_block.cell_outputs.m_nft_token.pluck(:type_hash).uniq)
        end
      benchmark :recalculate_udt_transactions_count, local_tip_block
      benchmark :recalculate_dao_contract_transactions_count, local_tip_block
      benchmark :decrease_records_count, local_tip_block

      ApplicationRecord.benchmark "invalid! block" do
        local_tip_block.invalid!
      end

      benchmark :recalculate_udt_accounts, udt_type_hashes, local_tip_block
      benchmark :update_address_balance_and_ckb_transactions_count, local_tip_block
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
    snapshots = AddressBlockSnapshot.where.not(block_id: local_tip_block.id).where(address_id: local_tip_block.address_ids).order(block_number: :desc).distinct.group_by(&:address_id)
    local_tip_block.contained_addresses.each do |address|
      snapshot = snapshots.fetch(address.id, []).first
      if snapshot.present?
        attrs = snapshot.final_state
        address.update!(attrs)
      else
        address.live_cells_count = address.cell_outputs.live.count
        # address.ckb_transactions_count = address.custom_ckb_transactions.count
        address.ckb_transactions_count = AccountBook.where(address_id: address.id).count
        address.dao_transactions_count = AddressDaoTransaction.where(address_id: address.id).count
        address.cal_balance!
        address.save!
      end
    end

    AddressBlockSnapshot.where(block_id: local_tip_block.id).delete_all
  end

  def recalculate_dao_contract_transactions_count(local_tip_block)
    dao_transactions_count = local_tip_block.ckb_transactions.where("tags @> array[?]::varchar[]", ["dao"]).count
    if dao_transactions_count > 0
      DaoContract.default_contract.decrement!(:ckb_transactions_count,
                                              dao_transactions_count)
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
          updated_at: Time.current
        }
      end

    Udt.upsert_all(udt_counts_value) if udt_counts_value.present?
  end

  def revert_dao_contract_related_operations(local_tip_block)
    dao_events = DaoEvent.where(block: local_tip_block).processed
    dao_contract = DaoContract.default_contract
    revert_withdraw_from_dao(dao_contract, dao_events)
    revert_issue_interest(dao_contract, dao_events)
    revert_deposit_to_dao(dao_contract, dao_events)
    revert_new_dao_depositor(dao_contract, dao_events)
    revert_take_away_all_deposit(dao_contract, dao_events)
  end

  def recalculate_udt_accounts(udt_type_hashes, local_tip_block)
    return if udt_type_hashes.blank?

    local_tip_block.contained_addresses.find_each do |address|
      udt_type_hashes.each do |type_hash|
        udt_account = address.udt_accounts.find_by(type_hash: type_hash)
        next if udt_account.blank?

        case udt_account.udt_type
        when "sudt"
          amount = address.cell_outputs.live.udt.where(type_hash: type_hash).sum(:udt_amount)
          udt_account.update!(amount: amount)
        when "m_nft_token"
          udt_account.destroy
        when "nrc_721_token"
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
    dao_contract = DaoContract.default_contract
    revert_withdraw_from_dao(dao_contract, dao_events)
    revert_issue_interest(dao_contract, dao_events)
    revert_deposit_to_dao(dao_contract, dao_events)
    revert_new_dao_depositor(dao_contract, dao_events)
    revert_take_away_all_deposit(dao_contract, dao_events)
  end

  def revert_take_away_all_deposit(dao_contract, dao_events)
    take_away_all_deposit_dao_events = dao_events.where(event_type: "take_away_all_deposit")
    take_away_all_deposit_dao_events.each do |event|
      dao_contract.increment!(:depositors_count)
      event.reverted!
    end
  end

  def revert_issue_interest(dao_contract, dao_events)
    issue_interest_dao_events = dao_events.where(event_type: "issue_interest")
    issue_interest_dao_events.each do |event|
      dao_contract.decrement!(:claimed_compensation, event.value)
      address = event.address
      address.decrement!(:interest, event.value)
      event.reverted!
    end
  end

  def revert_withdraw_from_dao(dao_contract, dao_events)
    withdraw_from_dao_events = dao_events.where(event_type: "withdraw_from_dao")
    withdraw_from_dao_events.each do |event|
      dao_contract.decrement!(:withdraw_transactions_count)
      dao_contract.increment!(:total_deposit, event.value)
      address = event.address
      address.increment!(:dao_deposit, event.value)
      event.reverted!
    end
  end

  def revert_new_dao_depositor(dao_contract, dao_events)
    new_dao_depositor_events = dao_events.where(event_type: "new_dao_depositor")
    new_dao_depositor_events.each do |event|
      dao_contract.decrement!(:depositors_count)
      dao_contract.decrement!(:total_depositors_count)
      event.reverted!
    end
  end

  def revert_deposit_to_dao(dao_contract, dao_events)
    deposit_to_dao_events = dao_events.where(event_type: "deposit_to_dao")
    deposit_to_dao_events.each do |event|
      address = event.address
      address.decrement!(:dao_deposit, event.value)
      dao_contract.decrement!(:total_deposit, event.value)
      dao_contract.decrement!(:deposit_transactions_count)
      event.reverted!
    end
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
