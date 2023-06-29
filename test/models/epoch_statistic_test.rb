require "test_helper"

class EpochStatisticTest < ActiveSupport::TestCase
  setup do
    CkbSync::Api.any_instance.stubs(:get_blockchain_info).returns(OpenStruct.new(chain: "ckb_testnet"))
  end

  test "max_cycles_block should return the block with the largest cycles" do
    prepare_node_data(10)
    epoch_statistic = create(:epoch_statistic, epoch_number: 0)
    block = Block.where(epoch: 0).where.not(cycles: nil).order(cycles: :desc).first
    assert_equal block, epoch_statistic.max_cycles_block
  end

  test "max_cycles_tx should return the transactions with the largest cycles" do
    prepare_node_data(10)
    epoch_statistic = create(:epoch_statistic, epoch_number: 0)
    txs = CkbTransaction.joins(:block).where(blocks: { epoch: 0 }).where.not(cycles: nil).order(cycles: :desc).first
    assert_equal txs, epoch_statistic.max_cycles_tx
  end

  test "largest_block should return the block with the largest block_size" do
    prepare_node_data(10)
    epoch_statistic = create(:epoch_statistic, epoch_number: 0)
    block = Block.where(epoch: 0).where.not(block_size: nil).order(block_size: :desc).first
    assert_equal block, epoch_statistic.largest_block
  end

  test "largest_tx should return the transactions with the largest bytes" do
    prepare_node_data(10)
    epoch_statistic = create(:epoch_statistic, epoch_number: 0)
    txs = CkbTransaction.joins(:block).where(blocks: { epoch: 0 }).where.not(bytes: nil).order(bytes: :desc).first
    assert_equal txs, epoch_statistic.largest_tx
  end

  test "difficulty should return the first block difficulty in epoch" do
    prepare_node_data(10)
    epoch_statistic = create(:epoch_statistic, epoch_number: 0)
    block = Block.where(epoch: 0).order(:number).first
    epoch_statistic.reset :difficulty
    assert_equal block.difficulty.to_s, epoch_statistic.difficulty
  end

  test "uncle_rate should return the average uncle rate of epoch's blocks" do
    prepare_node_data(10)
    epoch_statistic = create(:epoch_statistic, epoch_number: 0)
    blocks = Block.where(epoch: 0)
    uncle_rate = blocks.sum(:uncles_count).to_d / blocks.count
    epoch_statistic.reset :uncle_rate
    assert_equal uncle_rate.to_s, epoch_statistic.uncle_rate
  end

  test "hash_rate should return the average hash rate of epoch's blocks" do
    prepare_node_data(10)
    epoch_statistic = create(:epoch_statistic, epoch_number: 0)
    blocks = Block.where(epoch: 0).order(:number)
    difficulty = blocks.first.difficulty
    epoch_length = blocks.first.length
    epoch_time = blocks.last.timestamp - blocks.first.timestamp
    hash_rate = difficulty * epoch_length / epoch_time
    epoch_statistic.reset :hash_rate
    assert_equal hash_rate.to_s, epoch_statistic.hash_rate
  end

  test "epoch_time should return the time interval of epoch" do
    prepare_node_data(10)
    epoch_statistic = create(:epoch_statistic, epoch_number: 0)
    blocks = Block.where(epoch: 0).order(:number)
    epoch_time = blocks.last.timestamp - blocks.first.timestamp
    epoch_statistic.reset :epoch_time
    assert_equal epoch_time, epoch_statistic.epoch_time
  end

  test "epoch_length should return the epoch length" do
    prepare_node_data(10)
    epoch_statistic = create(:epoch_statistic, epoch_number: 0)
    epoch_length = Block.where(epoch: 0).pick(:length)
    epoch_statistic.reset :epoch_length
    assert_equal epoch_length, epoch_statistic.epoch_length
  end

  test "largest_tx_hash should return the epoch transactions largest tx_hash" do
    prepare_node_data(10)
    epoch_statistic = create(:epoch_statistic, epoch_number: 0)
    txs = CkbTransaction.joins(:block).where(blocks: { epoch: 0 }).order(bytes: :desc).first
    epoch_statistic.reset :largest_tx_hash
    assert_equal txs.tx_hash, epoch_statistic.largest_tx_hash
  end

  test "largest_tx_bytes should return the epoch transactions largest bytes" do
    prepare_node_data(10)
    epoch_statistic = create(:epoch_statistic, epoch_number: 0)
    txs = CkbTransaction.joins(:block).where(blocks: { epoch: 0 }).order(bytes: :desc).first
    epoch_statistic.reset :largest_tx_bytes
    assert_equal txs.bytes, epoch_statistic.largest_tx_bytes
  end

  test "max_tx_cycles should return the epoch transactions largest cycles" do
    prepare_node_data(10)
    epoch_statistic = create(:epoch_statistic, epoch_number: 0)
    txs = CkbTransaction.joins(:block).where(blocks: { epoch: 0 }).
      where.not(cycles: nil).order(cycles: :desc).first
    epoch_statistic.reset :max_tx_cycles
    assert_equal txs.cycles, epoch_statistic.max_tx_cycles
  end

  test "max_block_cycles should return the epoch blocks largest cycles" do
    prepare_node_data(10)
    epoch_statistic = create(:epoch_statistic, epoch_number: 0)
    block = Block.where(epoch: 0).where.not(cycles: nil).order(cycles: :desc).first
    epoch_statistic.reset :max_block_cycles
    assert_equal block.cycles, epoch_statistic.max_block_cycles
  end

  test "largest_block_number should return the number of the block corresponding to the maximum block_size" do
    prepare_node_data(10)
    epoch_statistic = create(:epoch_statistic, epoch_number: 0)
    blocks = Block.where(epoch: 0)
    blocks.each { |block| block.update(block_size: Faker::Number.number(digits: 4)) }
    block = blocks.where.not(block_size: nil).order(block_size: :desc).first
    epoch_statistic.reset :largest_block_number
    assert_equal block.number, epoch_statistic.largest_block_number
  end

  test "largest_block_size should return the block_size of the block corresponding to the maximum block_size" do
    prepare_node_data(10)
    epoch_statistic = create(:epoch_statistic, epoch_number: 0)
    blocks = Block.where(epoch: 0)
    blocks.each { |block| block.update(block_size: Faker::Number.number(digits: 4)) }
    block = blocks.where.not(block_size: nil).order(block_size: :desc).first
    epoch_statistic.reset :largest_block_size
    assert_equal block.block_size, epoch_statistic.largest_block_size
  end
end
