# frozen_string_literal: true

module CsvExportable
  class ExportBlockTransactionsJob < BaseExporter
    def perform(args)
      blocks = Block.select(:id, :miner_hash, :number, :timestamp, :reward, :ckb_transactions_count,
                            :live_cell_changes, :updated_at)

      if args[:start_date].present?
        start_date = BigDecimal(args[:start_date])
        blocks = blocks.where("timestamp >= ?", start_date)
      end

      if args[:end_date].present?
        end_date = BigDecimal(args[:end_date])
        blocks = blocks.where("timestamp <= ?", end_date)
      end

      blocks = blocks.where("number >= ?", args[:start_number]) if args[:start_number].present?
      blocks = blocks.where("number <= ?", args[:end_number]) if args[:end_number].present?
      blocks = blocks.order(number: :desc).last(Settings.query_default_limit)

      rows = []
      blocks.each do |block|
        row = generate_row(block)
        next if row.blank?

        rows << row
      end

      header = ["Blockno", "Transactions", "UnixTimestamp", "Reward(CKB)", "Miner", "date(UTC)"]

      generate_csv(header, rows)
    end

    def generate_row(block)
      datetime = datetime_utc(block.timestamp)
      reward = CkbUtils.shannon_to_byte(BigDecimal(block.reward))

      [
        block.number,
        block.ckb_transactions_count,
        block.timestamp,
        reward,
        block.miner_hash,
        datetime,
      ]
    end
  end
end
