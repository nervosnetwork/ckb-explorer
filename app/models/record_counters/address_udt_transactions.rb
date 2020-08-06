module RecordCounters
  class AddressUdtTransactions
    def initialize(address, udt_id)
      @address = address
      @udt_id = udt_id
    end

    def total_count
      address.ckb_udt_transactions(udt_id).count
    end

    private

    attr_reader :address, :udt_id
  end
end
