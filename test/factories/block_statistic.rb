FactoryBot.define do
  factory :block_statistic do
    block_number { Faker::Number.number(2) }
    live_cells_count { Faker::Number.number(4) }
    dead_cells_count { Faker::Number.number(4) }
    hash_rate { Faker::Number.number(20) }
    difficulty { Faker::Number.number(20) }
  end
end
