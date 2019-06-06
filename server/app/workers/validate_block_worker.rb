class ValidateBlockWorker
  include Sidekiq::Worker
  sidekiq_options queue: "authentic_sync", lock: :until_executed

  def perform(block_hash)
    CkbSync::Validator.validate(block_hash)
  end
end
