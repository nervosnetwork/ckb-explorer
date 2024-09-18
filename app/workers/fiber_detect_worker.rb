class FiberDetectWorker
  include Sidekiq::Worker
  sidekiq_options queue: "fiber"

  def perform; end
end
