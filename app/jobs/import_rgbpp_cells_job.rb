class ImportRgbppCellsJob < ApplicationJob
  class MissingVoutError < StandardError; end
  class MissingAddressError < StandardError; end

  queue_as :bitcoin

  def perform(cell_ids)
    ApplicationRecord.transaction do
      cell_outputs = CellOutput.where(id: cell_ids)

      utxo_map = build_utxo_map(cell_outputs)
      raw_tx_data = fetch_raw_transactions!(utxo_map)
      transactions = build_transactions!(cell_outputs, raw_tx_data, utxo_map)

      vout_attributes = []
      op_returns_attributes = []
      vin_attributes = []
      bitcoin_transfers_attributes = []

      cell_outputs.each do |cell_output|
        utxo = utxo_map[cell_output.id]
        txid = utxo[:txid]
        out_index = utxo[:out_index]

        raw_tx = raw_tx_data[txid]
        tx = transactions[txid]

        next unless raw_tx && tx

        # build op_returns
        op_returns = build_op_returns!(raw_tx, tx, cell_output.ckb_transaction)
        op_returns_attributes.concat(op_returns).uniq! if op_returns.present?

        # build vouts
        vout = build_vout!(raw_tx, tx, out_index, cell_output)
        vout_attributes << vout if vout.present?

        # build vin
        vin = build_vin!(cell_output.id, tx)
        vin_attributes << vin if vin.present?

        # build transfer
        bitcoin_transfers_attributes << {
          bitcoin_transaction_id: tx.id,
          ckb_transaction_id: cell_output.ckb_transaction_id,
          lock_type: "rgbpp",
          cell_output_id: cell_output.id,
        }

      rescue StandardError => e
        Rails.logger.error("Handle rgbpp cell (id: #{cell_output.id}) failed: #{e.message}")
        raise e
      end

      if vout_attributes.present?
        BitcoinVout.upsert_all(vout_attributes,
                               unique_by: %i[bitcoin_transaction_id index cell_output_id])
      end

      if vin_attributes.present?
        BitcoinVin.upsert_all(vin_attributes,
                              unique_by: %i[ckb_transaction_id cell_input_id])
      end

      if op_returns_attributes.present?
        BitcoinVout.upsert_all(op_returns_attributes,
                               unique_by: %i[bitcoin_transaction_id index cell_output_id])
      end

      if bitcoin_transfers_attributes.present?
        BitcoinTransfer.upsert_all(bitcoin_transfers_attributes,
                                   unique_by: %i[cell_output_id])
      end
    end
  rescue StandardError => e
    Rails.logger.error("ImportRgbppCells failed: #{e.message}")
    Rails.logger.error("Backtrace:\n#{e.backtrace.join("\n")}")
    raise e
  end

  def build_utxo_map(cell_outputs)
    cell_outputs.each_with_object({}) do |cell_output, data|
      txid, out_index = CkbUtils.parse_rgbpp_args(cell_output.lock_script.args)
      data[cell_output.id] = { txid:, out_index: }
    end
  end

  def fetch_raw_transactions!(utxo_map)
    txids = utxo_map.values.map { _1[:txid] }.uniq

    raw_tx_data = {}
    txids.each do |txid|
      data = Rails.cache.read(txid)
      unless data
        data = rpc.getrawtransaction(txid, 2)
        Rails.cache.write(txid, data, expires_in: 30.minutes)
      end
      raw_tx_data[txid] = data["result"]
    end

    raw_tx_data
  end

  def build_transactions!(cell_outputs, raw_tx_data, utxo_map)
    transaction_attributes = {}

    cell_outputs.each do |cell_output|
      utxo = utxo_map[cell_output.id]
      txid = utxo[:txid]
      raw_tx = raw_tx_data[txid]

      next unless raw_tx

      created_at = Time.at((cell_output.block_timestamp / 1000).to_i).in_time_zone
      transaction_attributes[txid] = {
        txid: raw_tx["txid"],
        tx_hash: raw_tx["hash"],
        time: raw_tx["time"],
        block_hash: raw_tx["blockhash"],
        block_height: 0,
        created_at:,
      }
    end

    unique_transaction_attributes = transaction_attributes.values
    BitcoinTransaction.upsert_all(unique_transaction_attributes, unique_by: :txid)
    BitcoinTransaction.where(txid: unique_transaction_attributes.map { |tx| tx[:txid] }).index_by(&:txid)
  end

  def build_op_returns!(raw_tx, tx, ckb_tx)
    raw_tx["vout"].map do |vout|
      data = vout.dig("scriptPubKey", "hex")
      script_pubkey = Bitcoin::Script.parse_from_payload(data.htb)
      next unless script_pubkey.op_return?

      {
        bitcoin_transaction_id: tx.id,
        data:,
        index: vout.dig("n"),
        asm: vout.dig("scriptPubKey", "asm"),
        op_return: true,
        ckb_transaction_id: ckb_tx.id,
      }
    end.compact
  end

  def build_vout!(raw_tx, tx, out_index, cell_output)
    vout = raw_tx["vout"].find { _1["n"] == out_index }
    raise MissingVoutError, "Missing vout txid: #{raw_tx['txid']} index: #{out_index}" unless vout

    address_hash = vout.dig("scriptPubKey", "address")
    raise MissingAddressError, "Missing vout address: #{raw_tx['txid']} index: #{out_index}" unless address_hash

    address = build_address!(address_hash, cell_output)
    {
      bitcoin_transaction_id: tx.id,
      bitcoin_address_id: address.id,
      data: vout.dig("scriptPubKey", "hex"),
      index: vout.dig("n"),
      asm: vout.dig("scriptPubKey", "asm"),
      op_return: false,
      ckb_transaction_id: cell_output.ckb_transaction_id,
      cell_output_id: cell_output.id,
      address_id: cell_output.address_id,
    }
  end

  def build_address!(address_hash, cell_output)
    created_at = Time.at((cell_output.block_timestamp / 1000).to_i).in_time_zone
    bitcoin_address = BitcoinAddress.create_with(created_at:).find_or_create_by!(address_hash:)
    BitcoinAddressMapping.
      create_with(bitcoin_address_id: bitcoin_address.id).
      find_or_create_by!(ckb_address_id: cell_output.address_id)

    BtcAccountBook.find_or_create_by!(ckb_transaction_id: cell_output.ckb_transaction_id, bitcoin_address_id: bitcoin_address.id)

    bitcoin_address
  end

  def build_vin!(cell_id, tx)
    cell_input = CellInput.find_by(previous_cell_output_id: cell_id)
    previous_vout = BitcoinVout.find_by(cell_output_id: cell_id)
    return unless cell_input && previous_vout

    previous_cell_output = cell_input.output
    # check whether previous_cell_output utxo consumed
    if previous_cell_output.dead? && previous_vout.binding?
      previous_vout.update!(status: "normal", consumed_by_id: tx.id)
    end

    {
      previous_bitcoin_vout_id: previous_vout.id,
      ckb_transaction_id: cell_input.ckb_transaction_id,
      cell_input_id: cell_input.id,
    }
  end

  def rpc
    @rpc ||= Bitcoin::Rpc.instance
  end
end
