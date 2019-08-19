require "test_helper"

class BlockTest < ActiveSupport::TestCase
  context "associations" do
    should have_many(:ckb_transactions)
    should have_many(:uncle_blocks)
    should have_many(:cell_outputs)
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
    should validate_presence_of(:cell_consumed).on(:create)
    should validate_presence_of(:reward).on(:create)
    should validate_presence_of(:total_transaction_fee).on(:create)
    should validate_presence_of(:ckb_transactions_count).on(:create)
    should validate_presence_of(:total_cell_capacity).on(:create)
    should validate_presence_of(:status).on(:create)
    should define_enum_for(:status).with_values(Block::statuses.keys)
    should validate_numericality_of(:reward).
      is_greater_than_or_equal_to(0).on(:create)
    should validate_numericality_of(:total_transaction_fee).
      is_greater_than_or_equal_to(0).on(:create)
    should validate_numericality_of(:ckb_transactions_count).
      is_greater_than_or_equal_to(0).on(:create)
    should validate_numericality_of(:total_cell_capacity).
      is_greater_than_or_equal_to(0).on(:create)
    should validate_numericality_of(:cell_consumed).
      is_greater_than_or_equal_to(0).on(:create)
  end

  test "#invalid! change block status to abandoned when block is not verified" do
    prepare_node_data(9)
    local_block = Block.find_by(number: 9)
    VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
      local_block.invalid!
      assert_equal "abandoned", local_block.reload.status
    end
  end

  test "#invalid! delete all uncle blocks under the abandoned block" do
    prepare_node_data(HAS_UNCLES_BLOCK_NUMBER)
    local_block = Block.find_by(number: HAS_UNCLES_BLOCK_NUMBER)

    assert_not_empty local_block.uncle_blocks

    VCR.use_cassette("blocks/#{HAS_UNCLES_BLOCK_NUMBER}") do
      assert_changes -> { local_block.reload.uncle_blocks.count }, from: local_block.uncle_blocks.count, to: 0 do
        local_block.invalid!
      end
    end
  end

  test "#invalid! delete all ckb transactions under the abandoned block" do
    prepare_node_data(9)
    local_block = Block.find_by(number: 9)

    assert_not_empty local_block.ckb_transactions

    VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
      assert_changes -> { local_block.reload.ckb_transactions.count }, from: local_block.ckb_transactions.count, to: 0 do
        local_block.invalid!
      end
    end
  end

  test "#invalid! delete cell inputs under the abandoned block" do
    prepare_node_data(9)
    local_block = Block.find_by(number: 9)

    assert_not_empty local_block.cell_inputs

    VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
      assert_changes -> { local_block.reload.cell_inputs.count }, from: local_block.cell_inputs.count, to: 0 do
        local_block.invalid!
      end
    end
  end

  test "#invalid! delete cell outputs under the abandoned block" do
    prepare_node_data(9)
    local_block = Block.find_by(number: 9)

    assert_not_empty local_block.cell_outputs

    VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
      assert_changes -> { local_block.reload.cell_outputs.count }, from: local_block.cell_outputs.count, to: 0 do
        local_block.invalid!
      end
    end
  end

  test "#invalid! delete all lock script under the abandoned block" do
    prepare_node_data(9)
    local_block = Block.find_by(number: 9)
    origin_lock_scripts = local_block.cell_outputs.map(&:lock_script)

    assert_not_empty origin_lock_scripts

    VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
      assert_changes -> { local_block.reload.cell_outputs.map(&:lock_script).count }, from: origin_lock_scripts.count, to: 0 do
        local_block.invalid!
      end
    end
  end

  test "#invalid! delete all type script under the abandoned block" do
    prepare_node_data(9)
    local_block = Block.find_by(number: 9)
    origin_type_scripts = local_block.cell_outputs.map(&:type_script)

    assert_not_empty origin_type_scripts

    VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
      assert_changes -> { local_block.reload.cell_outputs.map(&:type_script).count }, from: origin_type_scripts.count, to: 0 do
        local_block.invalid!
      end
    end
  end

  test "#contained_addresses should return addresses under the block" do
    Block.all.each do |block|
      ckb_transactions_under_the_block = block.ckb_transactions
      addresses = ckb_transactions_under_the_block.map(&:addresses).flatten.uniq

      assert_equal addresses, block.contained_addresses
    end
  end

  test "#block_hash should decodes packed string" do
    block = create(:block)
    block_hash = block.block_hash

    assert_equal unpack_attribute(block, "block_hash"), block_hash
  end

  test "#parent_hash should decodes packed string" do
    block = create(:block)
    parent_hash = block.parent_hash

    assert_equal unpack_attribute(block, "parent_hash"), parent_hash
  end

  test "#transactions_root should decodes packed string" do
    block = create(:block)
    transactions_root = block.transactions_root

    assert_equal unpack_attribute(block, "transactions_root"), transactions_root
  end

  test "#proposals_hash should decodes packed string" do
    block = create(:block)
    proposals_hash = block.proposals_hash

    assert_equal unpack_attribute(block, "proposals_hash"), proposals_hash
  end

  test "#uncles_hash should decodes packed string" do
    block = create(:block)
    uncles_hash = block.uncles_hash

    assert_equal unpack_attribute(block, "uncles_hash"), uncles_hash
  end

  test "#uncle_block_hashes should decodes packed string" do
    CkbSync::Api.any_instance.stubs(:get_epoch_by_number).returns(
      CKB::Types::Epoch.new(
        epoch_reward: "250000000000",
        difficulty: "0x1000",
        length: "2000",
        number: "0",
        start_number: "0"
      )
    )
    VCR.use_cassette("blocks/#{HAS_UNCLES_BLOCK_NUMBER}") do
      node_block = CkbSync::Api.instance.get_block_by_number(HAS_UNCLES_BLOCK_NUMBER)
      CkbSync::NodeDataProcessor.new.process_block(node_block)
      block = Block.find_by(number: HAS_UNCLES_BLOCK_NUMBER)
      uncle_block_hashes = block.uncle_block_hashes

      assert_equal unpack_array_attribute(block, "uncle_block_hashes", block.uncles_count, ENV["DEFAULT_HASH_LENGTH"]), uncle_block_hashes
    end
  end

  test "#uncle_block_hashes should return super when uncle block hashes is empty" do
    block = create(:block, :with_uncle_block_hashes)
    uncle_block_hashes = block.uncle_block_hashes

    assert_equal unpack_array_attribute(block, "uncle_block_hashes", block.uncles_count, ENV["DEFAULT_HASH_LENGTH"]), uncle_block_hashes
  end

  test "#proposals should decodes packed string" do
    CkbSync::Api.any_instance.stubs(:get_epoch_by_number).returns(
      CKB::Types::Epoch.new(
        epoch_reward: "250000000000",
        difficulty: "0x1000",
        length: "2000",
        number: "0",
        start_number: "0"
      )
    )
    VCR.use_cassette("blocks/#{HAS_UNCLES_BLOCK_NUMBER}", record: :new_episodes) do
      node_block = CkbSync::Api.instance.get_block_by_number(HAS_UNCLES_BLOCK_NUMBER)
      node_block.instance_variable_set(:@proposals, ["0x98a4e0c18c"])
      CkbSync::NodeDataProcessor.new.process_block(node_block)
      block = Block.find_by(number: HAS_UNCLES_BLOCK_NUMBER)
      proposals = block.proposals

      assert_equal unpack_array_attribute(block, "proposals", block.proposals_count, ENV["DEFAULT_SHORT_HASH_LENGTH"]), proposals
    end
  end

  test "#proposals should return super when proposal transactions is empty" do
    block = create(:block, :with_proposals)
    proposals = block.proposals
    assert_equal unpack_array_attribute(block, "proposals", block.proposals_count, ENV["DEFAULT_SHORT_HASH_LENGTH"]), proposals
  end

  test "#proposals= should encode proposals" do
    block = create(:block)
    block.proposals = ["0xeab419c632", "0xeab410c634"]
    block.proposals_count = block.proposals.size
    block.save

    assert_equal unpack_array_attribute(block, "proposals", block.proposals_count, ENV["DEFAULT_SHORT_HASH_LENGTH"]), block.proposals
  end

  def node_data_processor
    CkbSync::NodeDataProcessor.new
  end
end
