FactoryBot.define do
  factory :block_statistic do
    block_number { Faker::Number.number(digits: 2) }
    live_cells_count { Faker::Number.number(digits: 4) }
    dead_cells_count { Faker::Number.number(digits: 4) }
    hash_rate { Faker::Number.number(digits: 20) }
    difficulty { Faker::Number.number(digits: 20) }
  end
end
