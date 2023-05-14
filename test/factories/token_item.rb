FactoryBot.define do
  factory :token_item do
    name { "my_token"}
    icon_url { "https://url.token.com/1.jpg" }
    metadata_url { "https://meta.token.com/1" }
    status { 1 }
  end
end
