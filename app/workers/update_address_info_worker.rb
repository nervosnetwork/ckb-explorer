class UpdateAddressInfoWorker
  include Sidekiq::Worker
  sidekiq_options queue: "low"

  def perform(block_number)
    address_attributes = []
    block = Block.find_by(number: block_number)
    return if block.blank?

    block.contained_addresses.select(:id, :mined_blocks_count, :created_at).each do |addr|
      next if addr.mined_blocks_count > 0

      address_attributes << {
        id: addr.id, balance: addr.cell_outputs.live.sum(:capacity),
        ckb_transactions_count: AccountBook.where(address_id: addr.id).count,
        live_cells_count: addr.cell_outputs.live.count,
        dao_transactions_count: addr.ckb_dao_transactions.count,
        created_at: addr.created_at, updated_at: Time.current
      }
    end
    if address_attributes.present?
      Address.upsert_all(address_attributes)
      block.contained_addresses.each(&:touch)
    end
  end
end
