module RecordCounters
  class Transactions
    def total_count
      TableRecordCount.find_by(table_name: "ckb_transactions")&.count
    end
  end
end
