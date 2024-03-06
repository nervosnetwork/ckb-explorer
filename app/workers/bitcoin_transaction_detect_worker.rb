class BitcoinTransactionDetectWorker
  include Sidekiq::Worker
  sidekiq_options queue: "bitcoin"

  def perform(block_id)
    block = Block.find_by(id: block_id)
    return unless block

    ApplicationRecord.transaction do
      vin_attributes = []
      block.cell_inputs.rgb.each do |cell_input|
        next unless cell_input.output

        prev_txid, vout_index = CkbUtils.parse_rgb_args(cell_input.lock_script.args)
        attributes = build_vin_attributes!(prev_txid, vout_index, cell_input)
        vin_attributes << attributes
      end

      if vin_attributes.present?
        BitcoinVin.upsert_all(
          vin_attributes,
          unique_by: %i[bitcoin_transaction_id previous_bitcoin_vout_id],
        )
      end

      utxos = []
      block.cell_outputs.rgb.each do |cell_output|
        txid, vout_index = CkbUtils.parse_rgb_args(cell_output.lock_script.args)
        utxos << {
          txid:,
          index: vout_index,
          ckb_transaction_id: cell_output.ckb_transaction_id,
          cell_output_id: cell_output.id,
        }
      end

      vout_attributes = utxos.map { _1[:txid] }.uniq.map do |txid|
        raw_tx = fetch_raw_tx!(txid)
        tx_id = build_tx!(raw_tx)
        build_vout_attributes!(raw_tx["vout"], txid, tx_id)
      end.flatten

      vout_attributes.each do |v|
        utxo = utxos.find { _1[:txid] == v[:txid] && _1[:index] == v[:index] }
        v.except!(:txid)
        v[:ckb_transaction_id] = utxo ? utxo[:ckb_transaction_id] : nil
        v[:cell_output_id] = utxo ? utxo[:cell_output_id] : nil
      end

      if vout_attributes.present?
        BitcoinVout.upsert_all(vout_attributes, unique_by: %i[bitcoin_transaction_id index])
      end
    end
  end

  private

  def fetch_raw_tx!(txid)
    Rails.cache.fetch(txid, expires_in: 3600) do
      # verbose set to 2 for JSON object
      rpc.getrawtransaction(txid, 2)
    end
  end

  def build_tx!(raw_tx)
    tx = BitcoinTransaction.find_by(txid: raw_tx["txid"])
    return tx.id if tx

    block_header = rpc.getblockheader(raw_tx["blockhash"])
    tx_attrs = {
      txid: raw_tx["txid"],
      hash: raw_tx["hash"],
      time: raw_tx["time"],
      block_hash: raw_tx["blockhash"],
      block_height: block_header["height"],
    }
    res = BitcoinTransaction.upsert(tx_attrs, unique_by: :txid)
    res.to_ary.dig(0, "id")
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
      bitcoin_transaction_id: prev_vout.bitcoin_transaction_id,
      ckb_transaction_id: cell_input.ckb_transaction_id,
    }
  end

  def build_vout_attributes!(raw_vouts, txid, tx_id)
    attrs = []
    raw_vouts.map do |raw_vout|
      address_hash = raw_vout.dig("scriptPubKey", "address")
      address = BitcoinAddress.find_or_create_by(address_hash:) if address.present?

      attr = {
        txid:,
        bitcoin_transaction_id: tx_id,
        bitcoin_address_id: address&.id,
        hex: raw_vout.dig("scriptPubKey", "hex"),
        index: raw_vout.dig("n"),
        asm: raw_vout.dig("scriptPubKey", "asm"),
      }
      script_pubkey = Bitcoin::Script.parse_from_payload(attr[:hex].htb)
      attr[:op_return] = script_pubkey.op_return?

      attrs << attr
    end

    attrs
  end

  def rpc
    @rpc ||= Bitcoin::Rpc.instance
  end
end
