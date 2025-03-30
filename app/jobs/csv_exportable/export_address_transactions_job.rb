module CsvExportable
  class ExportAddressTransactionsJob < BaseExporter
    def perform(args)
      address = Addresses::Explore.run!(key: args[:id])
      raise AddressNotFoundError if address.is_a?(NullAddress)

      tx_ids = AccountBook.joins(:ckb_transaction).
        where(address_id: args[:address_id]).
        order(block_number: :desc, tx_index: :desc).
        limit(Settings.query_default_limit)

      if args[:start_date].present?
        start_date = BigDecimal(args[:start_date])
        tx_ids = tx_ids.where("ckb_transactions.block_timestamp >= ?", start_date)
      end

      if args[:end_date].present?
        end_date = BigDecimal(args[:end_date])
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
      input_info = cell_infos(inputs)
      output_info = cell_infos(outputs)

      datetime = datetime_utc(transaction.block_timestamp)
      fee = parse_transaction_fee(transaction.transaction_fee)

      rows = []
      units = input_info.keys | output_info.keys
      units.each_with_index do |unit, index|
        data =
          if unit == "CKB"
            build_ckb_data(input_info[unit], output_info[unit])
          else
            build_udt_data(input_info[unit], output_info[unit])
          end

        display_fee =
          if units.include?("CKB")
            units.length == 1 || (units.length > 1 && unit == "CKB")
          else
            index == 0
          end
        token = unit == "CKB" ? unit : parse_udt_token(input_info[unit], output_info[unit])

        rows << [
          transaction.tx_hash,
          transaction.block_number,
          transaction.block_timestamp,
          token,
          data[:method],
          data[:token_in],
          data[:token_out],
          data[:balance_diff],
          (display_fee ? fee : "/"),
          datetime,
        ]
      end

      rows
    end

    def cell_infos(outputs)
      infos = Hash.new
      outputs.each do |output|
        cell = { capacity: output.capacity, cell_type: output.cell_type }
        if output.udt?
          cell.merge!(attributes_for_udt_cell(output))
        end

        unit = token_unit(cell)
        unless infos[unit]
          infos[unit] = cell
          next
        end

        info = infos[unit]
        info[:capacity] += cell[:capacity]

        if (cell_udt_info = cell[:udt_info]).present?
          info[:udt_info][:amount] += cell_udt_info[:amount]
        end
      end

      infos
    end
  end
end
