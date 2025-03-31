module CsvExportable
  class ExportOmigaInscriptionTransactionsJob < BaseExporter
    def perform(args)
      udt =
        if args[:status] == "closed"
          Udt.joins(:omiga_inscription_info).where(
            "omiga_inscription_infos.type_hash = ? and omiga_inscription_infos.mint_status = 1", args[:id]
          ).first
        else
          Udt.joins(:omiga_inscription_info).where(
            "udts.type_hash = ? or omiga_inscription_infos.type_hash = ?", args[:id], args[:id]
          ).order("block_timestamp DESC").first
        end
      ckb_transactions = udt.ckb_transactions

      if args[:start_date].present?
        start_date = BigDecimal(args[:start_date])
        ckb_transactions = ckb_transactions.where("block_timestamp >= ?",
                                                  start_date)
      end

      if args[:end_date].present?
        end_date = BigDecimal(args[:end_date])
        ckb_transactions = ckb_transactions.where("block_timestamp <= ?",
                                                  end_date)
      end

      if args[:start_number].present?
        ckb_transactions = ckb_transactions.where("block_number >= ?",
                                                  args[:start_number])
      end

      if args[:end_number].present?
        ckb_transactions = ckb_transactions.where("block_number <= ?",
                                                  args[:end_number])
      end

      ckb_transactions = ckb_transactions.includes(:inputs, :outputs).
        order(block_timestamp: :desc).limit(Settings.query_default_limit)

      rows = []
      ckb_transactions.find_in_batches(batch_size: 1000,
                                       order: :desc) do |transactions|
        transactions.each do |transaction|
          row = generate_row(transaction, udt)
          next if row.blank?

          rows << row
        end
      end

      header = [
        "Txn hash", "Blockno", "UnixTimestamp", "Method", "Token",
        "Amount", "date(UTC)"
      ]

      generate_csv(header, rows)
    end

    def generate_row(transaction, udt)
      inputs = transaction.inputs.omiga_inscription
      outputs = transaction.outputs.omiga_inscription

      datetime = datetime_utc(transaction.block_timestamp)
      unit = udt.symbol.presence || udt.name
      method =
        if inputs.blank? && outputs.present?
          "mint"
        elsif inputs.present? && outputs.present?
          "rebase_mint"
        else
          "unknown"
        end
      data = CkbUtils.parse_omiga_inscription_data(outputs.first.data)

      [
        transaction.tx_hash,
        transaction.block_number,
        transaction.block_timestamp,
        method,
        unit,
        data[:mint_limit],
        datetime,
      ]
    end
  end
end
