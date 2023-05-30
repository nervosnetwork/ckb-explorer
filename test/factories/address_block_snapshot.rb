FactoryBot.define do
  factory :address_block_snapshot do
    balance { rand((10_000_000 * 10**18)..(100_000_000 * 10**18)) }
    balance_occupied { rand((1_000_000 * 10**18)..(10_000_000 * 10**18)) }
    live_cells_count { rand(100..1000) }
    ckb_transactions_count { rand(100..1000) }
    dao_transactions_count { rand(100..1000) }
    address
    block
  end
end
