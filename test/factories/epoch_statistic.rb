FactoryBot.define do
  factory :epoch_statistic do
    epoch_number { Faker::Number.number(digits: 2) }
    uncle_rate { Faker::Number.number(digits: 20) }
    difficulty { Faker::Number.number(digits: 20) }
  end
end
