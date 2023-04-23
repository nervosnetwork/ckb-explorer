FactoryBot.define do
  factory :transaction_address_change do
    ckb_transaction
    address
    delta { "9.99" }
  end
end
