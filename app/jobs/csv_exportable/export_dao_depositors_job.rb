# frozen_string_literal: true

module CsvExportable
  class ExportDaoDepositorsJob < BaseExporter
    def perform(args)
      sql = "".dup

      if args[:start_date].present?
        sql << "ckb_transactions.block_timestamp >= #{BigDecimal(args[:start_date])}"
      end

      if args[:end_date].present?
        sql << " AND ckb_transactions.block_timestamp <= #{BigDecimal(args[:start_date])}"
      end

      if args[:start_number].present?
        sql << "ckb_transactions.block_number >= #{args[:start_number]}"
      end

      if args[:end_number].present?
        sql << " AND ckb_transactions.block_number <= #{args[:end_number]}"
      end

      rows = []
      CellOutput.left_joins(:ckb_transaction, :address).live.nervos_dao_deposit.where(sql).
        select("cell_outputs.*, ckb_transactions.block_number, ckb_transactions.block_timestamp").find_in_batches(batch_size: 1000) do |cells|
        cells.each do |cell|
          amount = CkbUtils.shannon_to_byte(BigDecimal(cell.capacity))
          datetime = datetime_utc(cell.block_timestamp)
          rows << [cell.address_hash, amount, cell.tx_hash, nil, cell.block_timestamp, datetime]
        end
      end

      CellOutput.left_joins(:ckb_transaction, :address).live.nervos_dao_withdrawing.where(sql).
        select("cell_outputs.*, ckb_transactions.block_number, ckb_transactions.block_timestamp").find_in_batches(batch_size: 1000) do |cells|
        cells.each do |cell|
          cell_input = cell.ckb_transaction.cell_inputs.nervos_dao_deposit.first
          previous_cell_output = cell_input.previous_cell_output
          previous_tx_hash = previous_cell_output.tx_hash
          amount = CkbUtils.shannon_to_byte(BigDecimal(previous_cell_output.capacity))
          datetime = datetime_utc(previous_cell_output.block_timestamp)
          rows << [previous_cell_output.address_hash, amount, cell.tx_hash, previous_tx_hash, previous_cell_output.block_timestamp, datetime]
        end
      end

      header = ["Address", "Capacity", "Txn hash", "Previous Txn hash", "UnixTimestamp", "date(UTC)"]
      generate_csv(header, rows)
    end
  end
end
