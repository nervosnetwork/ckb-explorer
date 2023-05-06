class UpdateH24CkbTransactionsCountOnUdtsWorker
  include Sidekiq::Worker
  sidekiq_options queue: "low"

  def perform
    Udt.find_each do |udt|
      udt.update_h24_ckb_transactions_count
    end
  end
end
