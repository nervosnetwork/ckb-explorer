class UpdateAddressInfoWorker
  include Sidekiq::Worker

  def perform(block_number)
    address_attributes = []
    block = Block.find_by(number: block_number)
    block.contained_addresses.select(:id, :created_at).each do |addr|
      address_attributes << { id: addr.id, balance: addr.cell_outputs.live.sum(:capacity), ckb_transactions_count: addr.custom_ckb_transactions.count,
                              live_cells_count: addr.cell_outputs.live.count, dao_transactions_count: addr.ckb_dao_transactions.count,
                              created_at: addr.created_at, updated_at: Time.current }
    end
    Address.upsert_all(address_attributes) if address_attributes.present?
  end
end
