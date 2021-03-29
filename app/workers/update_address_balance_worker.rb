class UpdateAddressBalanceWorker
  include Sidekiq::Worker

  def perform(address_id)
    addr = Address.where(address_id).select(:id).first
    addr.update(balance: addr.cell_outputs.live.sum(:capacity))
  end
end
