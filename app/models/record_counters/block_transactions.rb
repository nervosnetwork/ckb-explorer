module RecordCounters
  class BlockTransactions
    def initialize(block)
      @block = block
    end

    def total_count
      block.ckb_transactions_count
    end

    private

    attr_reader :block
  end
end
