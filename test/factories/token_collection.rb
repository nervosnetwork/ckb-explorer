FactoryBot.define do
  factory :token_collection do
    standard { "nrc721" }
    name { "my_token1" }
    description {}
    icon_url {}
    items_count { 0 }
    holders_count { 0 }
    symbol {}
    sn { "sn-#{SecureRandom.hex(32)}" }
    type_script

    trait :with_items do
      after(:create) do |collection, _evaluator|
        10.times do |i|
          create(:token_item, token_id: i, collection:)
        end

        holders_count = collection.items.normal.count("distinct owner_id")
        collection.update(items_count: 10, holders_count:)
      end
    end
  end
end
