FactoryBot.define do
  factory :statistic_info do
    transactions_last_24hrs { "" }
    transactions_count_per_minute { "" }
    average_block_time { "" }
    hash_rate { "9.99" }
    address_balance_ranking { "" }
    miner_ranking { "" }
    blockchain_info { "MyString" }
    last_n_days_transaction_fee_rates { "" }
  end
end
