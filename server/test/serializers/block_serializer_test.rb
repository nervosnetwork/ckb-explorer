require "test_helper"

class BlockSerializerTest < ActiveSupport::TestCase
  test "should contain correct keys" do
    block = create(:block)

    assert_equal %i(block_hash number proposal_transactions_count uncles_count uncle_block_hashes miner_hash timestamp difficulty version nonce proof transactions_count reward total_transaction_fee cell_consumed total_cell_capacity).sort, BlockSerializer.new(block).serializable_hash.dig(:data, :attributes).keys.sort
  end

  test "should return reward converted to ckb" do
    block = create(:block, reward: 10000)

    assert_equal 0.0001, BlockSerializer.new(block).serializable_hash.dig(:data, :attributes, :reward)
  end

  test "should return total_transaction_fee converted to ckb" do
    block = create(:block, total_transaction_fee: 1000)

    assert_equal 0.00001, BlockSerializer.new(block).serializable_hash.dig(:data, :attributes, :total_transaction_fee)
  end

  test "should return cell_consumed converted to ckb" do
    block = create(:block, cell_consumed: 100)

    assert_equal 0.000001, BlockSerializer.new(block).serializable_hash.dig(:data, :attributes, :cell_consumed)
  end

  test "should return total_cell_capacity converted to ckb" do
    block = create(:block, total_cell_capacity: 10000)

    assert_equal 0.0001, BlockSerializer.new(block).serializable_hash.dig(:data, :attributes, :total_cell_capacity)
  end
end
