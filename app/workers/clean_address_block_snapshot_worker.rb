class CleanAddressBlockSnapshotWorker
  include Sidekiq::Worker
  sidekiq_options queue: "low"

  KEEP_COUNT = 30

  def perform
    # struct: [[address_id, count]]
    results = AddressBlockSnapshot.group(:address_id).having("count(*) > 50").count

    results.each do |result|
      AddressBlockSnapshot.where(address_id: result[0]).order("block_id asc").limit(result[1] - KEEP_COUNT).delete_all
    end
  end
end
