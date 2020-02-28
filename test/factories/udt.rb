FactoryBot.define do
  factory :udt do
    code_hash { "0x#{SecureRandom.hex(32)}" }
    hash_type { "type" }
    args { "0x" }
    udt_type { "sudt" }
    full_name { "kingdom fat coin" }
    symbol { "kfc" }
    decimal { 6 }
    total_amount { 100000000000 * 10**6 }
  end
end
