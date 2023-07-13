FactoryBot.define do
  factory :address_block_snapshot do
    final_state do
      {
        balance: 10_000_000 * 10**8,
        balance_occupied: 1_000_000 * 10**8,
        live_cells_count: 100,
        ckb_transactions_count: 233,
        dao_transactions_count: 39
      }
    end
    address
    block
  end
end
