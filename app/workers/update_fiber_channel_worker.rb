class UpdateFiberChannelWorker
  include Sidekiq::Worker
  sidekiq_options queue: "fiber"

  def perform
    # check channel is closed
    FiberGraphChannel.with_deleted.open_channels.each do |channel|
      funding_cell = channel.funding_cell
      if funding_cell.consumed_by
        channel.update(closed_transaction_id: funding_cell.consumed_by_id)
        FiberAccountBook.upsert(
          {
            fiber_graph_channel_id: channel.id,
            ckb_transaction_id: funding_cell.consumed_by_id,
            address_id: funding_cell.address_id,
          }, unique_by: %i[address_id ckb_transaction_id]
        )
      end
    end
  end
end
