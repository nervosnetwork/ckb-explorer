FactoryBot.define do
  factory :cell_datum do
    cell_output
    data { SecureRandom.hex }
  end
end
