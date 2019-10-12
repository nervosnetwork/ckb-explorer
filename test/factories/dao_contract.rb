FactoryBot.define do
  factory :dao_contract do
    total_deposit { 10**8 * 1_000_000 }
  end
end
