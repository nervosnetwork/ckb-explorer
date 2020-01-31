FactoryBot.define do
  factory :dao_contract do
    total_deposit { 10**8 * 1_000_000 }
    depositors_count { 1000 }
    unclaimed_compensation { 0 }
  end
end
