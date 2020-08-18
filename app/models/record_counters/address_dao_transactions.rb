module RecordCounters
  class AddressDaoTransactions
    def initialize(address)
      @address = address
    end

    def total_count
      address.dao_transactions_count
    end

    private

    attr_reader :address
  end
end
