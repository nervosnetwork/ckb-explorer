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

    Address.where(id: contained_address_ids).find_in_batches(batch_size: 100).with_index do |group, batch|
      puts "Processing group ##{batch}"
      address_attributes = []

      group.each do |addr|
        # puts addr.id
        balance, balance_occupied = addr.cal_balance
        address_attributes << {
          id: addr.id,
          balance: balance,
          balance_occupied: balance_occupied,
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
