require "test_helper"

class UncleBlockTest < ActiveSupport::TestCase
  context "associations" do
    should belong_to(:block)
  end

  context "validations" do
    should validate_presence_of(:block_hash).on(:create)
    should validate_presence_of(:number).on(:create)
    should validate_presence_of(:parent_hash).on(:create)
    should validate_presence_of(:seal).on(:create)
    should validate_presence_of(:timestamp).on(:create)
    should validate_presence_of(:transactions_root).on(:create)
    should validate_presence_of(:proposals_hash).on(:create)
    should validate_presence_of(:uncles_count).on(:create)
    should validate_presence_of(:uncles_hash).on(:create)
    should validate_presence_of(:version).on(:create)
  end

  test "#block_hash should decodes packed string" do
    block = create(:block)
    uncle_block = create(:uncle_block, block: block)
    block_hash = uncle_block.block_hash

    assert_equal unpack_attribute(uncle_block, "block_hash"), block_hash
  end

  test "#parent_hash should decodes packed string" do
    block = create(:block)
    uncle_block = create(:uncle_block, block: block)
    parent_hash = uncle_block.parent_hash

    assert_equal unpack_attribute(uncle_block, "parent_hash"), parent_hash
  end

  test "#transactions_root should decodes packed string" do
    block = create(:block)
    uncle_block = create(:uncle_block, block: block)
    transactions_root = uncle_block.transactions_root

    assert_equal unpack_attribute(uncle_block, "transactions_root"), transactions_root
  end

  test "#proposals_hash should decodes packed string" do
    block = create(:block)
    uncle_block = create(:uncle_block, block: block)
    proposals_hash = uncle_block.proposals_hash

    assert_equal unpack_attribute(uncle_block, "proposals_hash"), proposals_hash
  end

  test "#uncles_hash should decodes packed string" do
    block = create(:block)
    uncle_block = create(:uncle_block, block: block)
    uncles_hash = uncle_block.uncles_hash

    assert_equal unpack_attribute(uncle_block, "uncles_hash"), uncles_hash
  end

  test "#proposals should decodes packed string" do
    VCR.use_cassette("blocks/2") do
      SyncInfo.local_inauthentic_tip_block_number
      block_hash = "0x2f8cd9eeb04e2c57c8192e77d6f5cf64630201fd23b1d7c0b89edd73033efbba"
      node_block = CkbSync::Api.instance.get_block(block_hash)
      node_block.uncles.first.instance_variable_set(:@proposals, ["0x98a4e0c18c"])
      create(:sync_info, name: "inauthentic_tip_block_number", value: node_block.header.number)
      set_default_lock_params(node_block: node_block)

      CkbSync::Persist.save_block(node_block, "inauthentic")
      block = Block.find_by(block_hash: block_hash)
      uncle_block = block.uncle_blocks.first
      proposals = uncle_block.proposals

      assert_equal unpack_array_attribute(uncle_block, "proposals", uncle_block.proposals_count, ENV["DEFAULT_SHORT_HASH_LENGTH"]), proposals
    end
  end

  test "#proposals should return super when proposal transactions is empty" do
    block = create(:block)
    uncle_block = create(:uncle_block, block: block)
    uncle_block.update(proposals: [])
    proposals = uncle_block.proposals

    assert_nil proposals
  end

  test "#proposals= should encode proposals" do
    block = create(:block)
    uncle_block = create(:uncle_block, block: block)
    uncle_block.proposals = ["0xeab419c632", "0xeab410c634"]
    uncle_block.proposals_count = uncle_block.proposals.size
    uncle_block.save

    assert_equal unpack_array_attribute(uncle_block, "proposals", uncle_block.proposals_count, ENV["DEFAULT_SHORT_HASH_LENGTH"]), uncle_block.proposals
  end
end
