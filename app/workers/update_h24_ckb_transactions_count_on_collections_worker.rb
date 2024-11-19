class UpdateH24CkbTransactionsCountOnCollectionsWorker
  include Sidekiq::Worker
  sidekiq_options queue: "low"

  def perform
    TokenItem.joins(:collection).includes(:collection).where("token_items.updated_at > ?", 1.hour.ago).each do |item|
      item.collection.update_h24_ckb_transactions_count
    end
  end
end
