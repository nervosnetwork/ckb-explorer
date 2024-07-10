# frozen_string_literal: true

module CsvExportable
  class ExportDaoDepositorsJob < BaseExporter
    def perform(args)
      start_date, end_date = extract_dates(args)
      deposit_rows = fetch_deposit_rows(start_date, end_date)
      withdrawing_rows = fetch_withdrawing_rows(start_date, end_date)
      combined_rows = combine_rows(deposit_rows, withdrawing_rows)

      header = ["Address", "Capacity"]
      generate_csv(header, combined_rows)
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
      rows = {}

      CellOutput.includes(:address).live.nervos_dao_deposit.where(sql).find_in_batches(batch_size: 500) do |cells|
        cells.each do |cell|
          address_hash = cell.address_hash
          amount = CkbUtils.shannon_to_byte(BigDecimal(cell.capacity))
          rows[address_hash] = rows.fetch(address_hash, 0) + amount
        end
      end

      rows
    end

    def fetch_withdrawing_rows(start_date, end_date)
      sql = build_sql_query(start_date, end_date)
      rows = {}

      CellOutput.includes(:address).live.nervos_dao_withdrawing.where(sql).find_in_batches(batch_size: 500) do |cells|
        cells.each do |cell|
          previous_cell_output = cell.ckb_transaction.input_cells.nervos_dao_deposit&.first
          next unless previous_cell_output

          address_hash = previous_cell_output.address_hash
          amount = CkbUtils.shannon_to_byte(BigDecimal(previous_cell_output.capacity))
          rows[address_hash] = rows.fetch(address_hash, 0) + amount
        end
      end

      rows
    end

    def combine_rows(deposit_rows, withdrawing_rows)
      combined = deposit_rows.merge(withdrawing_rows) { |_key, old_val, new_val| old_val + new_val }
      combined.map { |address, amount| [address, amount] }
    end
  end
end
