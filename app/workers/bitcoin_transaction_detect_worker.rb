class BitcoinTransactionDetectWorker
  include Sidekiq::Worker
  sidekiq_options queue: "bitcoin"

  def perform(block_id)
    block = Block.find_by(id: block_id)
    return unless block

    ApplicationRecord.transaction do
      block.ckb_transactions.each do |transaction|
        vin_attributes = []

        # import cell_inputs utxo
        transaction.cell_inputs.each do |cell|
          previous_cell_output = cell.previous_cell_output
          next unless previous_cell_output

          lock_script = previous_cell_output.lock_script
          next unless CkbUtils.is_rgbpp_lock_cell?(lock_script)

          # import previous bitcoin transaction if prev vout is missing
          import_utxo!(lock_script.args, previous_cell_output.id)

          previous_vout = BitcoinVout.find_by(cell_output_id: previous_cell_output.id)
          vin_attributes << {
            previous_bitcoin_vout_id: previous_vout.id,
            ckb_transaction_id: transaction.id,
            cell_input_id: cell.id,
          }
        end

        if vin_attributes.present?
          BitcoinVin.upsert_all(vin_attributes, unique_by: %i[ckb_transaction_id cell_input_id])
        end

        # import cell_outputs utxo
        transaction.cell_outputs.each do |cell|
          lock_script = cell.lock_script
          next unless CkbUtils.is_rgbpp_lock_cell?(lock_script)

          import_utxo!(lock_script.args, cell.id)
        end

        # update transaction rgbpp tags
        update_rgbpp_tags!(transaction)
      end
    end
  end

  def import_utxo!(args, cell_id)
    txid, out_index = CkbUtils.parse_rgbpp_args(args)

    unless BitcoinTransaction.includes(:bitcoin_vouts).where(
      bitcoin_transactions: { txid: },
      bitcoin_vouts: { index: out_index, cell_output_id: cell_id },
    ).exists?
      ImportBitcoinUtxoJob.perform_now(cell_id)
    end
  end

  def update_rgbpp_tags!(transaction)
    if transaction.bitcoin_vins.exists? || transaction.bitcoin_vouts.exists?
      transaction.update!(tags: transaction.tags.to_a + ["rgbpp"])
    end
  end
end
