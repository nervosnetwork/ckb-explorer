# frozen_string_literal: true

module CsvExportable
  class ExportContractTransactionsJob < BaseExporter
    def perform(args)
      dao_contract = DaoContract.default_contract
      ckb_transactions = dao_contract.ckb_transactions.includes(dao_events: [:address]).tx_committed

      if args[:start_date].present?
        start_date = BigDecimal(args[:start_date])
        ckb_transactions = ckb_transactions.where("ckb_transactions.block_timestamp >= ?", start_date)
      end

      if args[:end_date].present?
        end_date = BigDecimal(args[:end_date])
        ckb_transactions = ckb_transactions.where("ckb_transactions.block_timestamp <= ?", end_date)
      end

      if args[:start_number].present?
        ckb_transactions = ckb_transactions.where("ckb_transactions.block_number >= ?", args[:start_number])
      end

      if args[:end_number].present?
        ckb_transactions = ckb_transactions.where("ckb_transactions.block_number <= ?", args[:end_number])
      end

      ckb_transactions = ckb_transactions.order("ckb_transactions.block_timestamp desc nulls last, ckb_transactions.id desc").limit(5000)

      rows = []
      ckb_transactions.find_in_batches(batch_size: 1000, order: :desc) do |transactions|
        transactions.each do |transaction|
          row = generate_row(transaction)
          next if row.blank?

          rows += row
        end
      end

      header = [
        "Txn hash", "Address", "Blockno", "UnixTimestamp", "Method",
        "Amount", "Token", "TxnFee(CKB)", "date(UTC)"
      ]

      generate_csv(header, rows)
    end

    def generate_row(transaction)
      dao_events = transaction.dao_events.where(event_type: ["deposit_to_dao", "withdraw_from_dao", "issue_interest"])

      rows = []
      dao_events.each do |dao_event|
        datetime = datetime_utc(transaction.block_timestamp)
        fee = parse_transaction_fee(transaction.transaction_fee)
        amount = CkbUtils.shannon_to_byte(BigDecimal(dao_event.value))
        method = {
          "deposit_to_dao" => "Deposit",
          "withdraw_from_dao" => "Withdraw Request",
          "issue_interest" => "Withdraw Finalization",
        }[dao_event.event_type]

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
  end
end
