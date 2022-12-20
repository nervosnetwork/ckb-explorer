FactoryBot.define do
  factory :dao_event do
    block { create(:block, :with_block_hash) }
    address
    ckb_transaction
    status { "pending" }
  end

  factory :dao_event_with_block, class: 'DaoEvent' do
    block
    address
    ckb_transaction
    status { "pending" }
  end
end
