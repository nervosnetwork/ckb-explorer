# frozen_string_literal: true

module CsvExportable
  class ExportDaoDepositorsJob < BaseExporter
    def perform(args)
      start_date, end_date = extract_dates(args)

      rows = fetch_deposit_rows(start_date, end_date) + fetch_withdrawing_rows(start_date, end_date)

      header = ["Address", "Capacity", "Txn hash", "Previous Txn hash", "UnixTimestamp", "date(UTC)"]
      generate_csv(header, rows)
    end

    private

    def extract_dates(args)
      start_date = args[:start_date].present? ? BigDecimal(args[:start_date]) : nil
      end_date = args[:end_date].present? ? BigDecimal(args[:end_date]) : nil
      start_number = args[:start_number].presence
      end_number = args[:end_number].presence

      if start_number.present?
        start_date = Block.find_by(number: start_number)&.timestamp
      end

      if end_number.present?
        end_date = Block.find_by(number: end_number)&.timestamp
      end

      [start_date, end_date]
    end

    def build_sql_query(start_date, end_date)
      sql = "".dup
      sql << "block_timestamp >= #{start_date}" if start_date.present?
      sql << " AND " if start_date.present? && end_date.present?
      sql << "block_timestamp <= #{end_date}" if end_date.present?
      sql
    end

    def fetch_deposit_rows(start_date, end_date)
      sql = build_sql_query(start_date, end_date)
      rows = []

      CellOutput.includes(:address).live.nervos_dao_deposit.where(sql).find_in_batches(batch_size: 500) do |cells|
        cells.each do |cell|
          amount = CkbUtils.shannon_to_byte(BigDecimal(cell.capacity))
          datetime = datetime_utc(cell.block_timestamp)
          rows << [cell.address_hash, amount, cell.tx_hash, nil, cell.block_timestamp, datetime]
        end
      end

      rows
    end

    def fetch_withdrawing_rows(start_date, end_date)
      sql = build_sql_query(start_date, end_date)
      rows = []

      CellOutput.includes(:address).live.nervos_dao_withdrawing.where(sql).find_in_batches(batch_size: 500) do |cells|
        cells.each do |cell|
          cell_input = cell.ckb_transaction.cell_inputs.nervos_dao_deposit.first
          previous_cell_output = cell_input.previous_cell_output
          previous_tx_hash = previous_cell_output.tx_hash
          amount = CkbUtils.shannon_to_byte(BigDecimal(previous_cell_output.capacity))
          datetime = datetime_utc(previous_cell_output.block_timestamp)
          rows << [previous_cell_output.address_hash, amount, cell.tx_hash, previous_tx_hash, previous_cell_output.block_timestamp, datetime]
        end
      end

      rows
    end
  end
end
