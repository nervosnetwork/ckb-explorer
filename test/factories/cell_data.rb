FactoryBot.define do
  factory :cell_datum do
    cell_output
    data { SecureRandom.random_bytes }
  end
end
