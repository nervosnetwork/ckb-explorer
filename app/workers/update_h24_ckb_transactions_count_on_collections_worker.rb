class UpdateH24CkbTransactionsCountOnCollectionsWorker
  include Sidekiq::Worker
  sidekiq_options queue: "low"

  def perform
    TokenCollection.find_each do |collection|
      collection.update_h24_ckb_transactions_count
    end
  end
end
