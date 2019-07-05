require "test_helper"

module CkbSync
  class ValidatorTest < ActiveSupport::TestCase
    setup do
      create(:sync_info, name: "authentic_tip_block_number", value: 10)
      create(:sync_info, name: "inauthentic_tip_block_number", value: 10)
    end

    test "should change the existing block status to authentic when it is authenticated" do
      local_block = create(:block)
      VCR.use_cassette("blocks/10") do
        SyncInfo.local_authentic_tip_block_number
        assert_changes -> { local_block.reload.status }, from: "inauthentic", to: "authentic" do
          CkbSync::Validator.call(DEFAULT_NODE_BLOCK_HASH)
        end
      end
    end

    test "should create a new block when it is inauthenticated" do
      create(:block, block_hash: "0x419c632366c8eb9635acbb39ea085f7552ae62e1fdd480893375334a0f37d1bx")
      VCR.use_cassette("blocks/10") do
        SyncInfo.local_authentic_tip_block_number
        assert_difference "Block.count", 1 do
          CkbSync::Validator.call(DEFAULT_NODE_BLOCK_HASH)
        end
      end
    end

    test "should change the existing block status to abandoned when it is inauthenticated" do
      local_block = create(:block, block_hash: "0x419c632366c8eb9635acbb39ea085f7552ae62e1fdd480893375334a0f37d1bx")
      VCR.use_cassette("blocks/10") do
        SyncInfo.local_authentic_tip_block_number
        assert_changes -> { local_block.reload.status }, from: "inauthentic", to: "abandoned" do
          CkbSync::Validator.call(DEFAULT_NODE_BLOCK_HASH)
        end
      end
    end

    test "should change uncle blocks status to authentic when the existing block's status is authenticated" do
      local_block = nil
      block_hash = "0x2f8cd9eeb04e2c57c8192e77d6f5cf64630201fd23b1d7c0b89edd73033efbba"
      VCR.use_cassette("blocks/2") do
        create(:sync_info, name: "authentic_tip_block_number", value: 2)
        create(:sync_info, name: "inauthentic_tip_block_number", value: 2)
        node_block = CkbSync::Api.instance.get_block(block_hash)
        local_block = CkbSync::Persist.save_block(node_block, "inauthentic")
      end
      VCR.use_cassette("blocks/2") do
        assert_changes -> { local_block.reload.uncle_blocks.pluck(:status).uniq }, from: ["inauthentic"], to: ["authentic"] do
          CkbSync::Validator.call(block_hash)
        end
      end
    end

    test "should change uncle blocks status to abandoned when the existing block's status is inauthenticated" do
      block_hash = "0x2f8cd9eeb04e2c57c8192e77d6f5cf64630201fd23b1d7c0b89edd73033efbba"
      local_block = nil
      VCR.use_cassette("blocks/2") do
        create(:sync_info, name: "authentic_tip_block_number", value: 2)
        create(:sync_info, name: "inauthentic_tip_block_number", value: 2)
        node_block = CkbSync::Api.instance.get_block(block_hash)
        local_block = CkbSync::Persist.save_block(node_block, "inauthentic")
      end

      VCR.use_cassette("blocks/2") do
        assert_changes -> { local_block.reload.uncle_blocks.pluck(:status).uniq }, from: ["inauthentic"], to: ["authentic"] do
          CkbSync::Validator.call(block_hash)
        end
      end
    end
  end
end
