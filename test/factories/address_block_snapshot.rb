FactoryBot.define do
  factory :address_block_snapshot do
    final_state do
      {
        balance: rand(10_000_000..20_000_000) * 10**8,
        balance_occupied: rand(1_000_000..2_000_000) * 10**8,
        live_cells_count: rand(10..100),
        ckb_transactions_count: rand(100..200),
        dao_transactions_count: rand(10..50),
        last_updated_block_number: block.number
      }
    end
    address
    block
  end
end
