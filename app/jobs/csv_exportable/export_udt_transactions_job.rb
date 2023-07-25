module CsvExportable
  class ExportUdtTransactionsJob < BaseExporter
    def perform(args)
      udt = Udt.find_by!(type_hash: args[:id], published: true)
      ckb_transactions = udt.ckb_transactions

      if args[:start_date].present?
        start_date = DateTime.strptime(args[:start_date], "%Y-%m-%d").to_time.to_i * 1000
        ckb_transactions = ckb_transactions.where("block_timestamp >= ?", start_date)
      end

      if args[:end_date].present?
        end_date = DateTime.strptime(args[:end_date], "%Y-%m-%d").to_time.to_i * 1000
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
          row = generate_row(transaction)
          next if row.blank?

          rows += row
        end
      end

      header = [
        "Txn hash", "Blockno", "UnixTimestamp", "Token", "Method",
        "Token In", "Token Out", "Token From", "Token To", "TxnFee(CKB)", "date(UTC)"
      ]

      generate_csv(header, rows)
    end

    def generate_row(transaction)
      inputs = simple_display_inputs(transaction).compact
      outputs = simple_display_outputs(transaction)

      rows = []
      max = [inputs.size, outputs.size].max
      (0..max - 1).each do |i|
        units = capacity_units(outputs[i] || inputs[i])
        units.each do |unit|
          token_in = cell_capacity(inputs[i], unit)
          token_out = cell_capacity(outputs[i], unit)
          balance_change = token_out.to_f - token_in.to_f
          method = balance_change.positive? ? "PAYMENT RECEIVED" : "PAYMENT SENT"
          token_from = inputs[i].nil? ? "/" : inputs[i][:address_hash]
          token_to = outputs[i].nil? ? "/" : outputs[i][:address_hash]
          datetime = datetime_utc(transaction.block_timestamp)
          fee = parse_transaction_fee(transaction.transaction_fee)

          rows << [
            transaction.tx_hash,
            transaction.block_number,
            transaction.block_timestamp,
            unit,
            method,
            (token_in || "/"),
            (token_out || "/"),
            token_from,
            token_to,
            (unit == "CKB" ? fee : "/"),
            datetime
          ]
        end
      end

      rows
    end

    def simple_display_inputs(transaction)
      cell_inputs = transaction.cell_inputs.order(id: :asc)
      cell_inputs.map do |cell_input|
        previous_cell_output = cell_input.previous_cell_output
        next unless previous_cell_output
        next unless previous_cell_output.udt?

        display_input = {
          id: previous_cell_output.id,
          capacity: previous_cell_output.capacity,
          address_hash: previous_cell_output.address_hash
        }
        display_input.merge!(attributes_for_udt_cell(previous_cell_output))
        CkbUtils.hash_value_to_s(display_input)
      end
    end

    def simple_display_outputs(transaction)
      cell_outputs = transaction.outputs.udt.order(id: :asc)
      cell_outputs.map do |cell_output|
        display_output = {
          id: cell_output.id,
          capacity: cell_output.capacity,
          address_hash: cell_output.address_hash
        }
        display_output.merge!(attributes_for_udt_cell(cell_output))
        CkbUtils.hash_value_to_s(display_output)
      end
    end
  end
end
