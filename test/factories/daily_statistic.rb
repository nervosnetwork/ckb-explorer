FactoryBot.define do
  factory :daily_statistic do
    created_at_unixtimestamp { Time.zone.now.to_i }
    transactions_count { Faker::Number.number(4) }
    addresses_count { Faker::Number.number(4) }
    total_dao_deposit { Faker::Number.number(20) }
    occupied_capacity { Faker::Number.number(4) }
  end
end
