FactoryBot.define do
  factory :udt_account do
    address
    udt_type { "sudt" }
    full_name { "kingdom fat coin" }
    symbol { "kfc" }
    decimal { 6 }
    amount { 100000000000 * 10**6 }
  end
end
