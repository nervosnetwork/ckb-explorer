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

      input_capacities = cell_capacities(inputs)
      output_capacities = cell_capacities(outputs)

      rows = []
      datetime = datetime_utc(transaction.block_timestamp)
      unit =
        if udt.published
          udt.uan.presence || udt.symbol
        else
          type_hash = udt.type_hash
          "Unknown Token ##{type_hash[-4..]}"
        end

      (input_capacities.keys | output_capacities.keys).each do |address_hash|
        token_in = input_capacities[address_hash]
        token_out = output_capacities[address_hash]

        balance_change = token_out.to_f - token_in.to_f
        method = balance_change.negative? ? "PAYMENT SENT" : "PAYMENT RECEIVED"

        rows << [
          transaction.tx_hash,
          transaction.block_number,
          transaction.block_timestamp,
          method,
          unit,
          balance_change.abs,
          address_hash,
          datetime
        ]
      end

      rows
    end

    def cell_capacities(outputs)
      capacities = Hash.new { |hash, key| hash[key] = 0.0 }
      display_cells =
        outputs.map do |cell_output|
          display_cell = { capacity: cell_output.capacity, address_hash: cell_output.address_hash }
          display_cell.merge!(attributes_for_udt_cell(cell_output))
        end

      display_cells.each do |display_cell|
        unit = capacity_unit(display_cell)
        address_hash = display_cell[:address_hash]
        capacities[address_hash] += cell_capacity(display_cell, unit).to_f
      end

      capacities
    end
  end
end
