FactoryBot.define do
  factory :reject_reason do
    ckb_transaction { nil }
    message { "MyText" }
  end
end
