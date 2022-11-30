class CleanUpWorker
  include Sidekiq::Worker

  def perform
    TokenCollection.remove_corrupted
  end
end
