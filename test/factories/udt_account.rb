FactoryBot.define do
  factory :udt_account do
    udt
    address
    udt_type { "sudt" }
    full_name { "kingdom fat coin" }
    symbol { "kfc" }
    decimal { 6 }
    amount { 2**128 }
  end
end
