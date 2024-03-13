class SyncBitcoinTransactionTxidsWorker
  include Sidekiq::Worker
  sidekiq_options queue: "bitcoin"

  def perform
    tip_block_number = StatisticInfo.default.tip_block_number
    # The synchronization ratio of Bitcoin blocks
    bitcoin_block_number = tip_block_number / 20
    txids = Kredis.unique_list "bitcoin_#{bitcoin_block_number}"
    return if txids.elements.present?

    block_hash = rpc.getblockhash(bitcoin_block_number)
    # verbose set to 1 for JSON object
    block = rpc.getblock(block_hash, 1)
    txids.append(block["tx"].slice(1..-1))
  end

  private

  def rpc
    @rpc ||= Bitcoin::Rpc.instance
  end
end
