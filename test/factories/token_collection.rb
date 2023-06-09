FactoryBot.define do
  factory :token_collection do
    standard { "nrc721" }
    name { "my_token1"}
    description {}
    icon_url {}
    items_count { 30}
    holders_count { 20 }
    symbol {}
    sn {"sn-#{SecureRandom.hex(32)}"}
  end
end
