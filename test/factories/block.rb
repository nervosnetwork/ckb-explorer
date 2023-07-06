FactoryBot.define do
  factory :block do
    compact_target { "0x100" }
    block_hash { "0xfe658f33e9e6c8f1a1830b0bfc01a0c014b8e38ec3d132337d5f622a0fa58288" }
    number { 10 }
    parent_hash { "0xcba2d1a70602a1def80efbd59629c37a9d6c36f9de7a8ed6d1ca4f76389365e1" }
    nonce { 1757392074788233522 }
    # timestamp is associated with number, starting from 2020-01-01 00:00:00, the default block interval is 10s
    timestamp { 1577836800000 + number * 10000 }
    transactions_root { "0xe08894ef0ed80481448f7a584438a76b6bdbea178c02b4c3b40863d75c5aed3c" }
    proposals_hash { "0x0000000000000000000000000000000000000000000000000000000000000000" }
    uncles_count { 1 }
    extra_hash { "0xa43e4bb916f6d08f746a055271049d3a61a5344ad266553454862ef68d41bc4d" }
    version { 0 }
    cell_consumed { 43 }
    reward { 50000 }
    total_transaction_fee { 0 }
    ckb_transactions_count { 1 }
    total_cell_capacity { 50000 }
    uncle_block_hashes {}
    proposals {}
    epoch { "0" }
    start_number { "0" }
    length { "1000" }
    block_size { 2_000_000 }

    transient do
      transactions_count { 10 }
    end

    trait :with_block_hash do
      block_hash { "0x#{SecureRandom.hex(32)}" }
    end

    trait :with_block_number do
      number { Faker::Number.within(range: 100..10000) }
    end

    trait :with_proposals do
      proposals { ["0xb5658716ac", "0xb5658716ac"] }
      proposals_count { (proposals.size).to_s }
    end

    trait :with_uncle_block_hashes do
      uncle_block_hashes { ["0xa43e4bb916f6d08f746a055271049d3a61a5344ad266553454862ef68d41bc4d", "0xa43e4bb916f6d08f746a055271049d3a61a5344ad266553454862ef68d41bc3d"] }
      uncles_count { (uncle_block_hashes.size).to_s }
    end

    trait :with_ckb_transactions do
      after(:create) do |block, evaluator|
        create_list(:ckb_transaction, evaluator.transactions_count, block: block)
        block.update(ckb_transactions_count: evaluator.transactions_count)
      end
    end
  end
end
