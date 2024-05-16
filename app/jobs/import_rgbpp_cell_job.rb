class ImportRgbppCellJob < ApplicationJob
  class MissingVoutError < StandardError; end
  class MissingAddressError < StandardError; end

  queue_as :bitcoin

  def perform(cell_id)
    ApplicationRecord.transaction do
      cell_output = CellOutput.find_by(id: cell_id)
      return unless cell_output

      lock_script = cell_output.lock_script
      return unless CkbUtils.is_rgbpp_lock_cell?(lock_script)

      txid, out_index = CkbUtils.parse_rgbpp_args(lock_script.args)
      Rails.logger.info("Importing rgbpp cell #{cell_id} txid #{txid} out_index #{out_index}")

      # build bitcoin transaction
      raw_tx = fetch_raw_transaction(txid)
      return unless raw_tx

      tx = build_transaction!(raw_tx)
      # build op_returns
      vout_attributes = []
      op_returns = build_op_returns!(raw_tx, tx, cell_output.ckb_transaction)
      vout_attributes.concat(op_returns) if op_returns.present?
      # build vouts
      vout_attributes << build_vout!(raw_tx, tx, out_index, cell_output)
      if vout_attributes.present?
        BitcoinVout.upsert_all(
          vout_attributes,
          unique_by: %i[bitcoin_transaction_id index cell_output_id],
        )
      end
      # build vin
      build_vin!(cell_id, tx)
      # build transfer
      BitcoinTransfer.create_with(
        bitcoin_transaction_id: tx.id,
        ckb_transaction_id: cell_output.ckb_transaction_id,
        lock_type: "rgbpp",
      ).find_or_create_by!(
        cell_output_id: cell_id,
      )
    end
  rescue StandardError => e
    Rails.logger.error(e.message)
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

  def build_op_returns!(raw_tx, tx, ckb_tx)
    op_returns = []

    raw_tx["vout"].each do |vout|
      data = vout.dig("scriptPubKey", "hex")
      script_pubkey = Bitcoin::Script.parse_from_payload(data.htb)
      next unless script_pubkey.op_return?

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

      next if BitcoinVout.exists?(
        bitcoin_transaction_id: op_return[:bitcoin_transaction_id],
        index: op_return[:index],
      )

      op_returns << op_return
    end

    op_returns
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

  def build_vin!(cell_id, tx)
    cell_input = CellInput.find_by(previous_cell_output_id: cell_id)
    previous_vout = BitcoinVout.find_by(cell_output_id: cell_id)
    if cell_input && previous_vout
      BitcoinVin.create_with(
        previous_bitcoin_vout_id: previous_vout.id,
      ).find_or_create_by!(
        ckb_transaction_id: cell_input.ckb_transaction_id,
        cell_input_id: cell_input.id,
      )

      previous_cell_output = cell_input.output
      # check whether previous_cell_output utxo consumed
      if previous_cell_output.dead? && previous_vout.binding?
        previous_vout.update!(status: "normal", consumed_by_id: tx.id)
      end
    end
  end

  def build_address!(address_hash, cell_output)
    bitcoin_address = BitcoinAddress.find_or_create_by!(address_hash:)
    BitcoinAddressMapping.
      create_with(bitcoin_address_id: bitcoin_address.id).
      find_or_create_by!(ckb_address_id: cell_output.address_id)

    bitcoin_address
  end

  def fetch_raw_transaction(txid)
    data = Rails.cache.read(txid)
    data ||= rpc.getrawtransaction(txid, 2)
    Rails.cache.write(txid, data, expires_in: 10.minutes) unless Rails.cache.exist?(txid)
    data["result"]
  rescue StandardError => e
    Rails.logger.error "get bitcoin raw transaction #{txid} failed: #{e}"
    nil
  end

  def rpc
    @rpc ||= Bitcoin::Rpc.instance
  end
end
