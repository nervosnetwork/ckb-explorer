module RecordCounters
  class DaoTransactions
    def initialize(dao_contract)
      @dao_contract = dao_contract
    end

    def total_count
      dao_contract.ckb_transactions_count
    end

    private

    attr_reader :dao_contract
  end
end
