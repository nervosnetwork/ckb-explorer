FactoryBot.define do
  factory :daily_statistic do
    sequence(:created_at_unixtimestamp) { |n| n.days.ago.beginning_of_day.to_i }
    transactions_count { Faker::Number.number(digits: 4) }
    addresses_count { Faker::Number.number(digits: 4) }
    total_dao_deposit { Faker::Number.number(digits: 20) }
    occupied_capacity { Faker::Number.number(digits: 4) }
  end
end
