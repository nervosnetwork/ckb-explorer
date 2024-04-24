class ImportBitcoinUtxoJob < ApplicationJob
  queue_as :bitcoin

  def perform(cell_id)
    ApplicationRecord.transaction do
      cell_output = CellOutput.find_by(id: cell_id)
      unless cell_output
        raise ArgumentError, "Missing cell_output(#{cell_id})"
      end

      lock_script = cell_output.lock_script
      return unless CkbUtils.is_rgbpp_lock_cell?(lock_script)

      txid, out_index = CkbUtils.parse_rgbpp_args(lock_script.args)
      Rails.logger.info("Importing bitcoin utxo #{txid} out_index #{out_index}")
      vout_attributes = []
      # build bitcoin transaction
      raw_tx = rpc.getrawtransaction(txid, 2)
      tx = build_transaction!(raw_tx)
      # build op_returns
      op_returns = build_op_returns!(raw_tx, tx, cell_output.ckb_transaction, vout_attributes)
      vout_attributes.concat(op_returns) if op_returns.present?
      # build vout
      vout_attributes << build_vout!(raw_tx, tx, out_index, cell_output)

      if vout_attributes.present?
        BitcoinVout.upsert_all(
          vout_attributes,
          unique_by: %i[bitcoin_transaction_id index cell_output_id],
        )
      end
    end
  end

  def build_transaction!(raw_tx)
    tx = BitcoinTransaction.find_by(txid: raw_tx["txid"])
    return tx if tx

    # raw transactions may not include the block hash
    if raw_tx["blockhash"].present?
      block_header = rpc.getblockheader(raw_tx["blockhash"])
    end
    BitcoinTransaction.create!(
      txid: raw_tx["txid"],
      tx_hash: raw_tx["hash"],
      time: raw_tx["time"],
      block_hash: raw_tx["blockhash"],
      block_height: block_header&.dig("height") || 0,
    )
  end

  def build_op_returns!(raw_tx, tx, ckb_tx, v_attributes)
    op_returns = []

    raw_tx["vout"].each do |vout|
      data = vout.dig("scriptPubKey", "hex")
      script_pubkey = Bitcoin::Script.parse_from_payload(data.htb)
      next unless script_pubkey.op_return?

        # commiment = script_pubkey.op_return_data.bth
        # unless commiment == CkbUtils.calculate_commitment(ckb_tx.tx_hash)
        #   raise ArgumentError, "Invalid commitment found in the CKB VirtualTx"
        # end

      op_return = {
        bitcoin_transaction_id: tx.id,
        bitcoin_address_id: nil,
        data:,
        index: vout.dig("n"),
        asm: vout.dig("scriptPubKey", "asm"),
        op_return: true,
        ckb_transaction_id: ckb_tx.id,
        cell_output_id: nil,
        address_id: nil,
      }

      op_returns << op_return if v_attributes.exclude?(op_return)
    end

    op_returns
  end

  def build_vout!(raw_tx, tx, out_index, cell_output)
    vout = raw_tx["vout"].find { _1["n"] == out_index }
    raise ArgumentError, "Missing vout txid: #{raw_tx['txid']} index: #{out_index}" unless vout

    address_hash = vout.dig("scriptPubKey", "address")
    raise ArgumentError, "Missing vout address: #{raw_tx['txid']} index: #{out_index}" unless address_hash

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
    bitcoin_address = BitcoinAddress.find_or_create_by!(address_hash:)
    BitcoinAddressMapping.
      create_with(bitcoin_address_id: bitcoin_address.id).
      find_or_create_by!(ckb_address_id: cell_output.address_id)

    bitcoin_address
  end

  def rpc
    @rpc ||= Bitcoin::Rpc.instance
  end
end
