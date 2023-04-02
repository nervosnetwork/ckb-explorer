FactoryBot.define do
  factory :type_script do
    args { "0x#{SecureRandom.hex(32)}" }
    code_hash { "0x#{SecureRandom.hex(32)}" }
    hash_type { "type" }
    trait :with_contract do
      code_hash { "0x00000000000000000000000000000000000000000000000000545950455f4944" }
      hash_type { "type" }
    end
  end
end
