require "test_helper"

class UncleBlockTest < ActiveSupport::TestCase
  setup do
    create(:table_record_count, :block_counter)
    create(:table_record_count, :ckb_transactions_counter)
    CkbSync::Api.any_instance.stubs(:get_blockchain_info).returns(OpenStruct.new(chain: "ckb_testnet"))
    GenerateStatisticsDataWorker.any_instance.stubs(:perform).returns(true)
    CkbSync::Api.any_instance.stubs(:get_block_cycles).returns(
      [
        "0x100", "0x200", "0x300", "0x400", "0x500", "0x600", "0x700", "0x800", "0x900"
      ]
    )
  end

  context "associations" do
    should belong_to(:block)
  end

  context "validations" do
    should validate_presence_of(:block_hash).on(:create)
    should validate_presence_of(:number).on(:create)
    should validate_presence_of(:parent_hash).on(:create)
    should validate_presence_of(:timestamp).on(:create)
    should validate_presence_of(:transactions_root).on(:create)
    should validate_presence_of(:proposals_hash).on(:create)
    should validate_presence_of(:extra_hash).on(:create)
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

  test "#extra_hash should decodes packed string" do
    block = create(:block)
    uncle_block = create(:uncle_block, block: block)
    extra_hash = uncle_block.extra_hash

    assert_equal unpack_attribute(uncle_block, "extra_hash"), extra_hash
  end

  test "#proposals should decodes packed string" do
    CkbSync::Api.any_instance.stubs(:get_epoch_by_number).returns(
      CKB::Types::Epoch.new(
        compact_target: "0x1000",
        length: "0x07d0",
        number: "0x0",
        start_number: "0x0"
      )
    )
    VCR.use_cassette("blocks/#{HAS_UNCLES_BLOCK_NUMBER}") do
      node_block = CkbSync::Api.instance.get_block_by_number(HAS_UNCLES_BLOCK_NUMBER)
      create(:block, :with_block_hash, number: node_block.header.number - 1)
      node_block.uncles.first.instance_variable_set(:@proposals, ["0x98a4e0c18c"])

      CkbSync::NewNodeDataProcessor.new.process_block(node_block)
      create(:block, :with_block_hash, number: node_block.header.number - 1)
      block = Block.find_by(number: HAS_UNCLES_BLOCK_NUMBER)
      uncle_block = block.uncle_blocks.first
      proposals = uncle_block.proposals

      assert_equal unpack_array_attribute(uncle_block, "proposals", uncle_block.proposals_count, Settings.default_short_hash_length), proposals
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

    assert_equal unpack_array_attribute(uncle_block, "proposals", uncle_block.proposals_count, Settings.default_short_hash_length), uncle_block.proposals
  end
end
