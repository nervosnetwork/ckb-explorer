class CleanUpWorker
  include Sidekiq::Worker

  def perform
    TokenCollection.remove_corrupted
    CkbTransaction.tx_pending.where("created_at < ?", 2.weeks.ago).destroy_all
    CkbTransaction.tx_rejected.where("created_at < ?", 3.months.ago).destroy_all
  end
end
