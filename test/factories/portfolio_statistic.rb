FactoryBot.define do
  factory :portfolio_statistic do
    user
    capacity { Faker::Number.number(digits: 4) }
    occupied_capacity { Faker::Number.number(digits: 4) }
    dao_deposit { Faker::Number.number(digits: 10) }
    interest { Faker::Number.number(digits: 10) }
    unclaimed_compensation { Faker::Number.number(digits: 10) }
  end
end