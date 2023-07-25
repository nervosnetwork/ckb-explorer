module CsvExportable
  class ExportNFTTransactionsJob < BaseExporter
    def perform(args)
      collection = get_collection(args)
      token_transfers = TokenTransfer.
        joins(:item, :ckb_transaction).
        includes(:ckb_transaction, :from, :to).
        where("token_items.collection_id = ?", collection.id)

      if args[:start_date].present?
        start_date = DateTime.strptime(args[:start_date], "%Y-%m-%d").to_time.to_i * 1000
        token_transfers = token_transfers.where("ckb_transactions.block_timestamp >= ?", start_date)
      end

      if args[:end_date].present?
        end_date = DateTime.strptime(args[:end_date], "%Y-%m-%d").to_time.to_i * 1000
        token_transfers = token_transfers.where("ckb_transactions.block_timestamp <= ?", end_date)
      end

      if args[:start_number].present?
        token_transfers = token_transfers.where("ckb_transactions.block_number >= ?",
                                                args[:start_number])
      end

      if args[:end_number].present?
        token_transfers = token_transfers.where("ckb_transactions.block_number <= ?",
                                                args[:end_number])
      end

      token_transfers = token_transfers.order("token_transfers.id desc").limit(5000)

      rows = []
      token_transfers.find_in_batches(batch_size: 1000, order: :desc) do |transfers|
        transfers.each do |transfer|
          row = generate_row(transfer)
          next if row.blank?

          rows << row
        end
      end

      header = [
        "Txn hash", "Blockno", "UnixTimestamp", "NFT ID", "Method",
        "NFT From", "NFT to", "TxnFee(CKB)", "date(UTC)"
      ]

      generate_csv(header, rows)
    end

    def generate_row(transfer)
      transaction = transfer.ckb_transaction
      fee = parse_transaction_fee(transaction.transaction_fee)
      datetime = datetime_utc(transaction.block_timestamp)
      method =
        case transfer.action
        when "normal" then "Transfer"
        when "destruction" then "Burn"
        else "Mint"
        end

      [
        transaction.tx_hash,
        transaction.block_number,
        transaction.block_timestamp,
        transfer.item.token_id,
        method,
        transfer.from&.address_hash || "/",
        transfer.to&.address_hash || "/",
        fee,
        datetime
      ]
    end

    def get_collection(args)
      if args[:collection_id].present?
        if /\A\d+\z/.match?(args[:collection_id])
          TokenCollection.find args[:collection_id]
        else
          TokenCollection.find_by_sn args[:collection_id]
        end
      end
    end
  end
end
