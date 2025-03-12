class UpdateFiberChannelWorker
  include Sidekiq::Worker
  sidekiq_options queue: "fiber"

  def perform
    # check channel is closed
    FiberGraphChannel.with_deleted.open_channels.each do |channel|
      funding_cell = channel.funding_cell
      if funding_cell.consumed_by
        channel.update(closed_transaction_id: funding_cell.consumed_by_id)
      end
    end
  end
end
