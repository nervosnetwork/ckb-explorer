module CsvExportable
  class ExportAddressTransactionsJob < BaseExporter
    def perform(args)
      tx_ids = AccountBook.joins(:ckb_transaction).
        where(address_id: args[:address_id]).
        order(ckb_transaction_id: :asc).
        limit(5000)

      if args[:start_date].present?
        start_date = DateTime.strptime(args[:start_date], "%Y-%m-%d").to_time.to_i * 1000
        tx_ids = tx_ids.where("ckb_transactions.block_timestamp >= ?", start_date)
      end

      if args[:end_date].present?
        end_date = DateTime.strptime(args[:end_date], "%Y-%m-%d").to_time.to_i * 1000
        tx_ids = tx_ids.where("ckb_transactions.block_timestamp <= ?", end_date)
      end

      if args[:start_number].present?
        tx_ids = tx_ids.where("ckb_transactions.block_number >= ?", args[:start_number])
      end

      if args[:end_number].present?
        tx_ids = tx_ids.where("ckb_transactions.block_number <= ?", args[:end_number])
      end

      ckb_transactions = CkbTransaction.where(id: tx_ids.pluck(:ckb_transaction_id))

      rows = []
      ckb_transactions.find_in_batches(batch_size: 500, order: :desc) do |transactions|
        tx_ids = transactions.pluck(:id)
        inputs = CellOutput.where(consumed_by_id: tx_ids, address_id: args[:address_id])
        outputs = CellOutput.where(ckb_transaction_id: tx_ids, address_id: args[:address_id])

        transactions.each do |transaction|
          tx_inputs = inputs.select { |input| input.consumed_by_id == transaction.id }.sort_by(&:id)
          tx_outputs = outputs.select { |output| output.ckb_transaction_id == transaction.id }.sort_by(&:id)

          row = generate_row(transaction, tx_inputs, tx_outputs)
          next if row.blank?

          rows += row
        end
      end

      header = [
        "Txn hash", "Blockno", "UnixTimestamp", "Token", "Method", "Token In",
        "Token Out", "Token Balance Change", "TxnFee(CKB)", "date(UTC)"
      ]

      generate_csv(header, rows)
    end

    def generate_row(transaction, inputs, outputs)
      input_capacities = cell_capacities(inputs)
      output_capacities = cell_capacities(outputs)

      datetime = datetime_utc(transaction.block_timestamp)
      fee = parse_transaction_fee(transaction.transaction_fee)

      rows = []
      units = input_capacities.keys | output_capacities.keys
      units.each do |unit|
        token_in = input_capacities[unit]
        token_out = output_capacities[unit]

        balance_change = token_out.to_f - token_in.to_f
        method = balance_change.positive? ? "PAYMENT RECEIVED" : "PAYMENT SENT"
        display_fee = units.length == 1 || (units.length > 1 && unit == "CKB")

        rows << [
          transaction.tx_hash,
          transaction.block_number,
          transaction.block_timestamp,
          unit,
          method,
          (token_in || "/"),
          (token_out || "/"),
          balance_change,
          (display_fee ? fee : "/"),
          datetime
        ]
      end

      rows
    end

    def cell_capacities(outputs)
      capacities = Hash.new
      display_cells =
        outputs.map do |cell_output|
          display_cell = { capacity: cell_output.capacity, cell_type: cell_output.cell_type }
          if cell_output.udt?
            display_cell.merge!(attributes_for_udt_cell(cell_output))
          end

          CkbUtils.hash_value_to_s(display_cell)
        end

      display_cells.each do |display_cell|
        unit = capacity_unit(display_cell)
        capacities[unit] = capacities[unit].to_f + cell_capacity(display_cell, unit).to_f
      end

      capacities
    end
  end
end
