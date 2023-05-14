FactoryBot.define do
  factory :token_item do
    token_id { Faker::Number.unique.number(digits: 2) }
    name { Faker::Name.unique.name }
    icon_url {}
    status { 1 }
  end
end
