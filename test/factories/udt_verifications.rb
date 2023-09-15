FactoryBot.define do
  factory :udt_verification do
    token { 123456 }
    sent_at { Time.now }
    last_ip { "127.0.0.1" }
    udt_type_hash { "0x#{SecureRandom.hex(32)}" }
    udt
  end
end
