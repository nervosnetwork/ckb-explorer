class BitcoinTransactionDetectWorker
  include Sidekiq::Worker
  sidekiq_options queue: "bitcoin"

  attr_accessor :block

  def perform(block_id)
    @block = Block.find_by(id: block_id)
    return unless @block

    ApplicationRecord.transaction do
      build_vins!
      build_vouts!
    end
  end

  private

  def build_vins!
    vin_attributes = []
    block.cell_inputs.each do |cell_input|
      next unless cell_input.output

      # prev_txid, vout_index = CkbUtils.parse_rgb_args(cell_input.lock_script.args)
      prev_txid, vout_index = get_txid(cell_input.output)
      if prev_txid && vout_index
        attributes = build_vin_attributes!(prev_txid, vout_index, cell_input)
        vin_attributes << attributes
      end
    end

    return if vin_attributes.blank?

    BitcoinVin.upsert_all(vin_attributes, unique_by: %i[ckb_transaction_id cell_input_id])
  end

  def build_vin_attributes!(prev_txid, vout_index, cell_input)
    prev_vout = BitcoinVout.includes(:bitcoin_transaction).find_by(
      bitcoin_transactions: { txid: prev_txid },
      bitcoin_vouts: { index: vout_index },
    )
    unless prev_vout
      raise ArgumentError, "Missing previous vout txid: #{prev_txid} index: #{vout_index}"
    end

    {
      previous_bitcoin_vout_id: prev_vout.id,
      ckb_transaction_id: cell_input.ckb_transaction_id,
      cell_input_id: cell_input.id,
    }
  end

  def build_vouts!
    utxos = []
    block.cell_outputs.each do |cell_output|
      txid, index = get_txid(cell_output)
      # txid, index = CkbUtils.parse_rgb_args(cell_output.lock_script.args)
      utxos << { txid:, index:, cell_output: } if txid && index
    end

    txids = utxos.map { _1[:txid] }.uniq
    vout_attributes = txids.map do |txid|
      # verbose set to 2 for JSON object
      raw_tx = rpc.getrawtransaction(txid, 2)
      tx = build_tx!(raw_tx)
      build_vout_attributes!(raw_tx, tx)
    end.flatten

    vout_attributes.each do |v|
      utxo = utxos.find { _1[:txid] == v[:txid] && _1[:index] == v[:index] }
      v[:ckb_transaction_id] = utxo&.dig(:cell_output)&.ckb_transaction_id
      v[:cell_output_id] = utxo&.dig(:cell_output)&.id
      v[:address_id] = utxo&.dig(:cell_output)&.address_id
      v.except!(:txid)
    end

    return if vout_attributes.blank?

    `BitcoinVout`.upsert_all(vout_attributes, unique_by: %i[bitcoin_transaction_id index])
  end

  def build_tx!(raw_tx)
    tx = BitcoinTransaction.find_by(txid: raw_tx["txid"])
    return tx if tx

    # avoid making multiple RPC requests
    block_header = rpc.getblockheader(raw_tx["blockhash"])
    BitcoinTransaction.create!(
      txid: raw_tx["txid"],
      hash: raw_tx["hash"],
      time: raw_tx["time"],
      block_hash: raw_tx["blockhash"],
      block_height: block_header["height"],
    )
  end

  def build_vout_attributes!(raw_tx, tx)
    raw_tx["vout"].map do |v|
      address_hash = v.dig("scriptPubKey", "address")
      address = BitcoinAddress.find_or_create_by(address_hash:) if address_hash.present?

      hex = v.dig("scriptPubKey", "hex")
      script_pubkey = Bitcoin::Script.parse_from_payload(hex.htb)
      op_return = script_pubkey.op_return?

      {
        txid: tx.txid,
        bitcoin_transaction_id: tx.id,
        bitcoin_address_id: address&.id,
        hex:,
        index: v.dig("n"),
        asm: v.dig("scriptPubKey", "asm"),
        op_return:,
      }
    end
  end

  def get_txid(cell)
    number = cell.ckb_transaction.block_number
    txids = Kredis.unique_list "bitcoin_#{number}"
    txid = txids.elements[0]

    raise ArgumentError, "Get rgb cell txid error" unless txid

    txids.remove(txid)

    [txid, cell.cell_index]
  end

  def rpc
    @rpc ||= Bitcoin::Rpc.instance
  end
end
