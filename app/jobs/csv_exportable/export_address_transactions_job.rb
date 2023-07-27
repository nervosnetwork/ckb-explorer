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

      ckb_transactions = CkbTransaction.includes(:inputs, :outputs).
        select(:id, :tx_hash, :transaction_fee, :block_id, :block_number, :block_timestamp, :updated_at).
        where(id: tx_ids.pluck(:ckb_transaction_id))

      rows = []
      ckb_transactions.find_in_batches(batch_size: 1000, order: :desc) do |transactions|
        transactions.each do |transaction|
          row = generate_row(transaction, args[:address_id])
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

    def generate_row(transaction, address_id)
      inputs = simple_display_inputs(transaction, address_id)
      outputs = simple_display_outputs(transaction, address_id)
      datetime = datetime_utc(transaction.block_timestamp)

      rows = []
      max = [inputs.size, outputs.size].max
      (0..max - 1).each do |i|
        units = capacity_units(outputs[i] || inputs[i])
        units.each do |unit|
          token_in = cell_capacity(inputs[i], unit)
          token_out = cell_capacity(outputs[i], unit)
          balance_change = token_out.to_f - token_in.to_f
          method = balance_change.positive? ? "PAYMENT RECEIVED" : "PAYMENT SENT"
          fee = parse_transaction_fee(transaction.transaction_fee)

          rows << [
            transaction.tx_hash,
            transaction.block_number,
            transaction.block_timestamp,
            unit,
            method,
            (token_in || "/"),
            (token_out || "/"),
            balance_change,
            (unit == "CKB" ? fee : "/"),
            datetime
          ]
        end
      end

      rows
    end

    def simple_display_inputs(transaction, address_id)
      previous_cell_outputs = transaction.inputs.where(address_id: address_id).order(id: :asc)
      previous_cell_outputs.map do |cell_output|
        display_input = { capacity: cell_output.capacity }
        if cell_output.udt?
          display_input.merge!(attributes_for_udt_cell(cell_output))
        end

        CkbUtils.hash_value_to_s(display_input)
      end
    end

    def simple_display_outputs(transaction, address_id)
      cell_outputs = transaction.outputs.where(address_id: address_id).order(id: :asc)
      cell_outputs.map do |cell_output|
        display_output = { capacity: cell_output.capacity }
        if cell_output.udt?
          display_output.merge!(attributes_for_udt_cell(cell_output))
        end

        CkbUtils.hash_value_to_s(display_output)
      end
    end
  end
end
