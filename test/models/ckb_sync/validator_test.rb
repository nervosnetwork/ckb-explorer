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
      CkbSync::Api.any_instance.stubs(:get_epoch_by_number).returns(
        CKB::Types::Epoch.new(
          epoch_reward: "250000000000",
          difficulty: "0x1000",
          length: "2000",
          number: "0",
          start_number: "0"
        )
      )
      local_block = nil
      VCR.use_cassette("blocks/#{HAS_UNCLES_BLOCK_NUMBER}") do
        create(:sync_info, name: "authentic_tip_block_number", value: HAS_UNCLES_BLOCK_NUMBER)
        create(:sync_info, name: "inauthentic_tip_block_number", value: HAS_UNCLES_BLOCK_NUMBER)
        node_block = CkbSync::Api.instance.get_block(HAS_UNCLES_BLOCK_HASH)
        local_block = CkbSync::Persist.save_block(node_block, "inauthentic")
      end
      VCR.use_cassette("blocks/#{HAS_UNCLES_BLOCK_NUMBER}") do
        assert_changes -> { local_block.reload.uncle_blocks.pluck(:status).uniq }, from: ["inauthentic"], to: ["authentic"] do
          CkbSync::Validator.call(HAS_UNCLES_BLOCK_HASH)
        end
      end
    end

    test "should change uncle blocks status to abandoned when the existing block's status is inauthenticated" do
      CkbSync::Api.any_instance.stubs(:get_epoch_by_number).returns(
        CKB::Types::Epoch.new(
          epoch_reward: "250000000000",
          difficulty: "0x1000",
          length: "2000",
          number: "0",
          start_number: "0"
        )
      )
      local_block = nil
      VCR.use_cassette("blocks/#{HAS_UNCLES_BLOCK_NUMBER}") do
        create(:sync_info, name: "authentic_tip_block_number", value: HAS_UNCLES_BLOCK_NUMBER)
        create(:sync_info, name: "inauthentic_tip_block_number", value: HAS_UNCLES_BLOCK_NUMBER)
        node_block = CkbSync::Api.instance.get_block(HAS_UNCLES_BLOCK_HASH)
        local_block = CkbSync::Persist.save_block(node_block, "inauthentic")
      end

      VCR.use_cassette("blocks/#{HAS_UNCLES_BLOCK_NUMBER}") do
        assert_changes -> { local_block.reload.uncle_blocks.pluck(:status).uniq }, from: ["inauthentic"], to: ["authentic"] do
          CkbSync::Validator.call(HAS_UNCLES_BLOCK_HASH)
        end
      end
    end
  end
end
