module CsvExportable
  class ExportUdtTransactionsJob < BaseExporter
    def perform(args)
      udt = Udt.find_by!(type_hash: args[:id], published: true)
      ckb_transactions = udt.ckb_transactions

      if args[:start_date].present?
        start_date = BigDecimal(args[:start_date])
        ckb_transactions = ckb_transactions.where("block_timestamp >= ?", start_date)
      end

      if args[:end_date].present?
        end_date = BigDecimal(args[:end_date])
        ckb_transactions = ckb_transactions.where("block_timestamp <= ?", end_date)
      end

      if args[:start_number].present?
        ckb_transactions = ckb_transactions.where("block_number >= ?", args[:start_number])
      end

      if args[:end_number].present?
        ckb_transactions = ckb_transactions.where("block_number <= ?", args[:end_number])
      end

      ckb_transactions = ckb_transactions.includes(:inputs, :outputs).
        order(block_timestamp: :desc).limit(5000)

      rows = []
      ckb_transactions.find_in_batches(batch_size: 1000, order: :desc) do |transactions|
        transactions.each do |transaction|
          row = generate_row(transaction, udt)
          next if row.blank?

          rows += row
        end
      end

      header = [
        "Txn hash", "Blockno", "UnixTimestamp", "Method", "Token",
        "Amount", "Token From", "date(UTC)"
      ]

      generate_csv(header, rows)
    end

    def generate_row(transaction, udt)
      inputs = transaction.inputs.udt
      outputs = transaction.outputs.udt

      input_info = cell_infos(inputs)
      output_info = cell_infos(outputs)
      datetime = datetime_utc(transaction.block_timestamp)

      rows = []
      unit =
        if udt.published
          udt.uan.presence || udt.symbol
        else
          type_hash = udt.type_hash
          "Unknown Token ##{type_hash[-4..]}"
        end

      address_hashes = input_info.keys | output_info.keys
      address_hashes.each do |address_hash|
        data = build_udt_data(input_info[address_hash], output_info[address_hash])
        rows << [
          transaction.tx_hash,
          transaction.block_number,
          transaction.block_timestamp,
          data[:method],
          unit,
          data[:balance_diff],
          address_hash,
          datetime
        ]
      end

      rows
    end

    def cell_infos(outputs)
      infos = Hash.new
      outputs.each do |output|
        cell = { capacity: output.capacity, address_hash: output.address_hash }
        cell.merge!(attributes_for_udt_cell(output))

        address_hash = cell[:address_hash]
        unless infos[address_hash]
          infos[address_hash] = cell
          next
        end

        info = infos[address_hash]
        info[:capacity] += cell[:capacity]
        info[:udt_info][:amount] += cell[:udt_info][:amount]
      end

      infos
    end
  end
end
