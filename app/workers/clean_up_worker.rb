class CleanUpWorker
  include Sidekiq::Worker

  def perform
    CkbTransaction.tx_pending.where("created_at < ?", 1.day.ago).destroy_all
    CkbTransaction.tx_rejected.where("created_at < ?", 3.months.ago).destroy_all
  end
end
