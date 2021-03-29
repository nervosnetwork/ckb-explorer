class UpdateAddressInfoWorker
  include Sidekiq::Worker

  def perform(address_id)
    addr = Address.where(id: address_id).select(:id).first
    addr.update_columns(ckb_transactions_count: addr.custom_ckb_transactions.count, live_cells_count: addr.cell_outputs.live.count, dao_transactions_count: addr.ckb_dao_transactions.count)
  end
end
