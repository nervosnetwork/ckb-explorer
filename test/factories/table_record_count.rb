FactoryBot.define do
  factory :table_record_count do
    table_name { "" }
    count { 0 }

    trait :block_counter do
      table_name { "blocks" }
    end

    trait :ckb_transactions_counter do
      table_name { "ckb_transactions" }
    end
  end
end
