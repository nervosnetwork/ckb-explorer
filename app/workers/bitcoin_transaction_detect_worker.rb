class BitcoinTransactionDetectWorker
  include Sidekiq::Worker
  sidekiq_options queue: "bitcoin"

  INIT_BITCOIN_BLOCK_HEIGHT = 100_000

  attr_accessor :block

  def perform(block_id)
    @block = Block.find_by(id: block_id)
    return unless @block

    ApplicationRecord.transaction do
      vout_attributes = []

      transacitons = @block.ckb_transactions.limit(min_transactions_count)
      transacitons.each_with_index do |transaction, index|
        next if transaction.bitcoin_vouts.exists?

        txid = bitcoin_txids[index]
        raw_transaction = rpc.getrawtransaction(txid, 2)
        bitcoin_transaction = build_tranaction!(raw_transaction)

        cell_output = transaction.cell_outputs.first
        vout_attribute = build_vout_attributes!(raw_transaction, bitcoin_transaction, cell_output)
        next unless vout_attribute

        vout_attributes << vout_attribute
      end

      return if vout_attributes.blank?

      BitcoinVout.upsert_all(vout_attributes, unique_by: %i[bitcoin_transaction_id index])
    end
  end

  private

  def bitcoin_txids
    return @txids if @txids

    block_hash = rpc.getblockhash(bitcoin_block_height)
    # verbose set to 1 for JSON object
    block = rpc.getblock(block_hash, 1)
    @txids = block["tx"]
  end

  def bitcoin_block_height
    transaction = BitcoinTransaction.last
    transaction ? transaction.block_height + 1 : 100_000
  end

  def min_transactions_count
    [block.ckb_transactions_count, bitcoin_txids.count].min
  end

  def build_tranaction!(raw_tx)
    tx = BitcoinTransaction.find_by(txid: raw_tx["txid"])
    return tx if tx

    # avoid making multiple RPC requests
    block_header = rpc.getblockheader(raw_tx["blockhash"])
    BitcoinTransaction.create!(
      txid: raw_tx["txid"],
      tx_hash: raw_tx["hash"],
      time: raw_tx["time"],
      block_hash: raw_tx["blockhash"],
      block_height: block_header["height"],
    )
  end

  def build_vout_attributes!(raw_tx, tx, cell_output)
    vout = raw_tx["vout"].find { _1["n"] == cell_output.cell_index }
    vout ||= raw_tx["vout"][0]

    address_hash = vout.dig("scriptPubKey", "address")
    return unless address_hash

    bitcoin_address = build_address!(address_hash, cell_output)

    {
      bitcoin_transaction_id: tx.id,
      bitcoin_address_id: bitcoin_address.id,
      data: "6a24aa21a9ed5e53af6963d02d7fcf87695798a0715951bd03fb05f524015d88324636141f42",
      index: vout.dig("scriptPubKey", "n"),
      asm: "OP_RETURN aa21a9ed5e53af6963d02d7fcf87695798a0715951bd03fb05f524015d88324636141f42",
      op_return: true,
      ckb_transaction_id: cell_output.ckb_transaction_id,
      cell_output_id: cell_output.id,
      address_id: cell_output.address_id,
    }
  end

  def build_address!(address_hash, cell_output)
    bitcoin_address = BitcoinAddress.find_or_create_by(address_hash:)
    BitcoinAddressMapping.
      create_with(bitcoin_address_id: bitcoin_address.id).
      find_or_create_by!(ckb_address_id: cell_output.address_id)

    bitcoin_address
  end

  def rpc
    @rpc ||= Bitcoin::Rpc.instance
  end
end
