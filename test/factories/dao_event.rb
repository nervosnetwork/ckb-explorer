FactoryBot.define do
  factory :dao_event do
    block { create(:block, :with_block_hash) }
    address
    ckb_transaction
    status { "processed" }
  end

  factory :dao_event_with_block, class: "DaoEvent" do
    block
    address
    ckb_transaction
    status { "processed" }
  end
end
