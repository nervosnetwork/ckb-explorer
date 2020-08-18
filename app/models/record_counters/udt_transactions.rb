module RecordCounters
  class UdtTransactions < Base
    def initialize(udt)
      @udt = udt
    end

    def total_count
      udt.ckb_transactions_count
    end

    private

    attr_reader :udt
  end
end
