class ImportBtcTimeCellsJob < ApplicationJob
  queue_as :bitcoin

  def perform(cell_ids)
    ApplicationRecord.transaction do
      cell_outputs = CellOutput.where(id: cell_ids)

      utxo_map = build_utxo_map(cell_outputs)
      raw_tx_data = fetch_raw_transactions!(utxo_map)
      transactions = build_transactions!(cell_outputs, raw_tx_data, utxo_map)

      bitcoin_transfers_attributes = []

      cell_outputs.each do |cell_output|
        txid = utxo_map[cell_output.id]
        tx = transactions[txid]

        # build transfer
        bitcoin_transfers_attributes << {
          bitcoin_transaction_id: tx.id,
          ckb_transaction_id: cell_output.ckb_transaction_id,
          lock_type: "btc_time",
          cell_output_id: cell_output.id,
        }
      rescue StandardError => e
        Rails.logger.error("Handle btc time cell (id: #{cell_output.id}) failed: #{e.message}")
        raise e
      end

      if bitcoin_transfers_attributes.present?
        BitcoinTransfer.upsert_all(bitcoin_transfers_attributes,
                                   unique_by: %i[cell_output_id])
      end
    end
  rescue StandardError => e
    Rails.logger.error("ImportBtcTimeCells failed: #{e.message}")
    Rails.logger.error("Backtrace:\n#{e.backtrace.join("\n")}")
    raise e
  end

  def build_utxo_map(cell_outputs)
    cell_outputs.each_with_object({}) do |cell_output, data|
      parsed_args = CkbUtils.parse_btc_time_lock_cell(cell_output.lock_script.args)
      data[cell_output.id] = parsed_args.txid
    end
  end

  def fetch_raw_transactions!(utxo_map)
    txids = utxo_map.values.uniq

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
      txid = utxo_map[cell_output.id]
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

  def rpc
    @rpc ||= Bitcoin::Rpc.instance
  end
end
