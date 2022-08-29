FactoryBot.define do
  factory :type_script do
    args { "0x" }
    code_hash { "0x#{SecureRandom.hex(32)}" }
    hash_type { "type" }
  end
end
