FactoryBot.define do
  factory :nrc_factory_cell do
    code_hash { "0x#{SecureRandom.hex(32)}" }
    hash_type { "type" }
    args { "0x" }
    name { "Test token factory" }
    symbol { "TTF" }
    base_token_uri { "http://test-token.com" }
    extra_data { "" }
    verified { false }
  end
end
