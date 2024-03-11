class SyncBitcoinTransactionTxidsWorker
  include Sidekiq::Worker
  sidekiq_options queue: "bitcoin"

  def perform
    txids = Kredis.unique_list "bitcoin_#{tip_block_number}"
    return if txids.elements.present?

    block_hash = rpc.getblockhash(tip_block_number / 20)
    # verbose set to 1 for JSON object
    block = rpc.getblock(block_hash, 1)
    txids.append(block["tx"].slice(1..-1))
  end

  private

  def tip_block_number
    # The synchronization ratio of Bitcoin blocks
    @number ||= StatisticInfo.default.tip_block_number
  end

  def rpc
    @rpc ||= Bitcoin::Rpc.instance
  end
end
