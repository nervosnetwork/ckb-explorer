FactoryBot.define do
  factory :witness do
    ckb_transaction
    index { 0 }
    data { Faker.datatype.hexadecimal }
  end
end
