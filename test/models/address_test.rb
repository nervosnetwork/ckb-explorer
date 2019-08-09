require "test_helper"

class AddressTest < ActiveSupport::TestCase
  context "associations" do
    should have_many(:account_books)
    should have_many(:ckb_transactions).
      through(:account_books)
  end

  test "address_hash should be nil when args is empty" do
    VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
      node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
      tx = node_block.transactions.first
      output = tx.outputs.first
      output.lock.instance_variable_set(:@args, [])

      CkbSync::NodeDataProcessor.new.process_block(node_block)
      block = Block.find_by(number: DEFAULT_NODE_BLOCK_NUMBER)
      address = block.contained_addresses.first

      assert_nil address.address_hash
    end
  end

  test ".find_or_create_address should return the address when the address_hash exists and use default lock script" do
    VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
      node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
      tx = node_block.transactions.first
      output = tx.outputs.first
      output.lock.instance_variable_set(:@args, ["0xabcbce98a758f130d34da522623d7e56705bddfe0dc4781bd2331211134a19a6"])
      output.lock.instance_variable_set(:@code_hash, ENV["CODE_HASH"])

      CkbSync::NodeDataProcessor.new.process_block(node_block)

      lock_script = node_block.transactions.first.outputs.first.lock

      assert_difference "Address.count", 0 do
        Address.find_or_create_address(lock_script)
      end
    end
  end

  test ".find_or_create_address should returned address's lock hash should equal with output's lock hash" do
    VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
      node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
      tx = node_block.transactions.first
      output = tx.outputs.first
      output.lock.instance_variable_set(:@args, ["0xabcbce98a758f130d34da522623d7e56705bddfe0dc4781bd2331211134a19a6"])
      output.lock.instance_variable_set(:@code_hash, ENV["CODE_HASH"])

      CkbSync::NodeDataProcessor.new.process_block(node_block)

      lock_script = node_block.transactions.first.outputs.first.lock
      address = Address.find_or_create_address(lock_script)

      assert_equal output.lock.to_hash, address.lock_hash
    end
  end
end
