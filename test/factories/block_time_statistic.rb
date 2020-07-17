FactoryBot.define do
  factory :block_time_statistic do
    stat_timestamp { Faker::Time.unique.between(from: 35.days.ago, to: Time.current).to_i }
    avg_block_time_per_hour { Faker::Number.decimal(l_digits: 2) }
  end
end
