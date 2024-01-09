FactoryBot.define do
  factory :omiga_inscription_info do
    udt_hash { "0x#{SecureRandom.hex(32)}" }
  end
end
