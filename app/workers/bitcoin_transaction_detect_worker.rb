class BitcoinTransactionDetectWorker
  include Sidekiq::Worker
  sidekiq_options queue: "bitcoin"

  def perform(txid, vout_index)
    # verbose set to 2 for JSON object
    raw_tx = rpc.getrawtransaction(txid, 2)

    ApplicationRecord.transaction do
      tx = build_transaction!(raw_tx)

      raw_vout = raw_tx["vout"].find { |h| h["n"] == vout_index }
      if raw_vout.empty?
        raise ArgumentError, "Invalid bitcoin vout index (#{vout_index}) with txid #{txid}"
      end

      build_vout!(raw_vout, tx)
    end
  end

  private

  def build_transaction!(raw_tx)
    block_header = rpc.getblockheader(raw_tx["blockhash"])

    tx_attributes = {
      txid: raw_tx["txid"],
      hash: raw_tx["hash"],
      time: raw_tx["time"],
      block_hash: raw_tx["blockhash"],
      block_height: block_header["height"],
    }
    BitcoinTransaction.upsert(tx_attributes, unique_by: :txid)
  end

  def build_vout!(raw_vout, tx)
    address_hash = raw_vout.dig("scriptPubKey", "address")
    address = BitcoinAddress.find_or_create_by(address_hash:) if address_hash

    vout_attributes = {
      bitcoin_transaction_id: tx.to_ary.dig(0, "id"),
      bitcoin_address_id: address&.id,
      hex: raw_vout.dig("scriptPubKey", "hex"),
      index: raw_vout.dig("n"),
      asm: raw_vout.dig("scriptPubKey", "asm"),
    }
    BitcoinVout.upsert(vout_attributes, unique_by: %i[bitcoin_transaction_id index])
  end

  def rpc
    @rpc ||= Bitcoin::Rpc.instance
  end
end
