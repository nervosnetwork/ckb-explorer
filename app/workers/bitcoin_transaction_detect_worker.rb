class BitcoinTransactionDetectWorker
  include Sidekiq::Worker
  sidekiq_options queue: "bitcoin"

  def perform(block_id)
    block = Block.find_by(id: block_id)
    return unless block

    utxos = []
    block.cell_inputs.rgb.each do |cell_input|
      next unless cell_input.previous_cell_output

      txid, index = parse_args(cell_input.lock_script.args)
      utxos << { cell_id: cell_input.previous_cell_output_id, txid:, index: }
    end

    block.cell_outputs.rgb.each do |cell_output|
      txid, index = parse_args(cell_output.lock_script.args)
      utxos << { cell_id: cell_output.id, txid:, index: }
    end

    utxos.each { fetch_utxo(_1) }
  end

  private

  def parse_args(_args)
    # TODO
    ["15dede3b31ed87bb6b1d668222127a7b308c1beb6fe99bf4a3f076bcae8e93fe", 4]
  end

  def fetch_utxo(utxo)
    # verbose set to 2 for JSON object
    raw_tx = rpc.getrawtransaction(utxo[:txid], 2)
    ApplicationRecord.transaction do
      tx = build_transaction!(raw_tx)

      raw_vout = raw_tx["vout"].find { |h| h["n"] == utxo[:index] }
      raise ArgumentError, "Sync bitcoin utxo failed: #{utxo}" if raw_vout.empty?

      build_vout!(raw_vout, tx, utxo[:cell_id])
    end
  end

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

  def build_vout!(raw_vout, tx, cell_id)
    address_hash = raw_vout.dig("scriptPubKey", "address")
    address = BitcoinAddress.find_or_create_by(address_hash:) if address_hash

    vout_attributes = {
      bitcoin_transaction_id: tx.to_ary.dig(0, "id"),
      bitcoin_address_id: address&.id,
      hex: raw_vout.dig("scriptPubKey", "hex"),
      index: raw_vout.dig("n"),
      asm: raw_vout.dig("scriptPubKey", "asm"),
      cell_output_id: cell_id,
    }
    BitcoinVout.upsert(vout_attributes, unique_by: %i[bitcoin_transaction_id index])
  end

  def rpc
    @rpc ||= Bitcoin::Rpc.instance
  end
end
