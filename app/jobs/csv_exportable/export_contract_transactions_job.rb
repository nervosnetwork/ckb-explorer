# frozen_string_literal: true

module CsvExportable
  class ExportContractTransactionsJob < BaseExporter
    def perform(args)
      start_date, end_date = extract_dates(args)
      transaction_rows = fetch_transaction_rows(start_date, end_date)
      header = [
        "Txn hash", "Address", "Blockno", "UnixTimestamp", "Method",
        "Amount", "Token", "TxnFee(CKB)", "date(UTC)"
      ]
      generate_csv(header, transaction_rows)
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

    def fetch_transaction_rows(start_date, end_date)
      sql = build_sql_query(start_date, end_date)
      rows = []

      dao_contract = DaoContract.default_contract
      dao_contract.ckb_transactions.includes(dao_events: [:address]).tx_committed.where(sql).
        order("block_timestamp desc nulls last, id desc").limit(5000).find_in_batches(batch_size: 500) do |transactions|
        transactions.each do |transaction|
          row = generate_row(transaction)
          next if row.blank?

          rows += row
        end
      end

      rows
    end

    def generate_row(transaction)
      dao_events = transaction.dao_events.where(event_type: ["deposit_to_dao", "withdraw_from_dao", "issue_interest"])

      rows = []
      dao_events.each do |dao_event|
        datetime = datetime_utc(transaction.block_timestamp)
        fee = parse_transaction_fee(transaction.transaction_fee)
        amount = CkbUtils.shannon_to_byte(BigDecimal(dao_event.value))
        method = map_event_type(dao_event.event_type)

        rows << [
          transaction.tx_hash,
          dao_event.address.address_hash,
          transaction.block_number,
          transaction.block_timestamp,
          method,
          amount,
          "CKB",
          fee,
          datetime,
        ]
      end

      rows
    end

    def map_event_type(event_type)
      {
        "deposit_to_dao" => "Deposit",
        "withdraw_from_dao" => "Withdraw Request",
        "issue_interest" => "Withdraw Finalization",
      }[event_type]
    end
  end
end
