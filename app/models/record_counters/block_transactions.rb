module RecordCounters
  class BlockTransactions
    def initialize(record)
      @record = record
    end

    def total_count
      if record.is_a?(Block)
        return record.ckb_transactions_count
      end

      record.count(:id)
    end

    private

    attr_reader :record
  end
end
