FactoryBot.define do
  factory :xudt_tag do
    udt
    udt_type_hash { "0x#{SecureRandom.hex(32)}" }
    tags { ["invalid"] }
  end
end
