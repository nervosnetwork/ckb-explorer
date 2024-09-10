FactoryBot.define do
  factory :type_script do
    args { "0x#{SecureRandom.hex(32)}" }
    code_hash { "0x#{SecureRandom.hex(32)}" }
    hash_type { "type" }
    trait :with_contract do
      code_hash { "0x00000000000000000000000000000000000000000000000000545950455f4944" }
      hash_type { "type" }
    end
    after(:build) { |ts, _context| ts.script_hash = CKB::Types::Script.new(code_hash: ts.code_hash, args: ts.args, hash_type: ts.hash_type).compute_hash }
  end
end
