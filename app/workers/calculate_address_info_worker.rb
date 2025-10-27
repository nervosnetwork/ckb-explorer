class CalculateAddressInfoWorker
  include Sidekiq::Worker
  sidekiq_options queue: "low"

  def perform()
    key = :last_block_for_update_addresses_info_worker
    id = Rails.cache.read(key)
    local_tip_block = Block.recent.first

    blocks = Block.where("id > ? and id <= ?", id, local_tip_block.id).order(id: :desc).select(:id, :address_ids)
    return if blocks.blank?

    contained_address_ids = Set.new
    blocks.each do |block|
      contained_address_ids.merge block.address_ids.map(&:to_i)
    end
    Rails.cache.write(key, local_tip_block.id)

    Address.where(id: contained_address_ids).find_in_batches do |group|
      sleep(50) # Make sure it doesn't get too crowded in there!
      address_attributes = []

      group.each do |addr|
        balance, balance_occupied = addr.cal_balance
        address_attributes << {
          id: addr.id,
          balance: balance,
          balance_occupied: balance_occupied,
          ckb_transactions_count: AccountBook.where(address_id: addr.id).count,
          live_cells_count: addr.cell_outputs.live.count,
          dao_transactions_count: addr.ckb_dao_transactions.count,
          created_at: addr.created_at,
          updated_at: Time.current
        }

        Rails.cache.delete_multi(%W(#{addr.class.name}/#{addr.lock_hash}))
      end

      if address_attributes.present?
        Address.upsert_all(address_attributes)
      end
    end
  end
end
