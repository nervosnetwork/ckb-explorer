FactoryBot.define do
  factory :epoch_statistic do
    epoch_number { Faker::Number.number(2) }
    uncle_rate { Faker::Number.number(20) }
    difficulty { Faker::Number.number(20) }
  end
end
