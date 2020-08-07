module RecordCounters
  class AddressTransactions
    def initialize(address)
      @address = address
    end

    def total_count
      address.ckb_transactions_count
    end

    private

    attr_reader :address
  end
end
