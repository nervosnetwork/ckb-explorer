require "simplecov"
SimpleCov.start "rails" do
  add_filter "/app/channels/"
  add_filter "/app/jobs/"
  add_filter "/app/mailers/"
  add_filter "/lib/api/"
  add_filter "/lib/fast_jsonapi"
  add_filter "/lib/ckb_block_node_processor.rb"
  add_filter "/lib/ckb_statistic_info_chart_data_updater.rb"
end
require "database_cleaner"
require "minitest/reporters"
require "mocha/minitest"
require "sidekiq/testing"
Minitest::Reporters.use!

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
DEFAULT_NODE_BLOCK_HASH = "0xfe658f33e9e6c8f1a1830b0bfc01a0c014b8e38ec3d132337d5f622a0fa58288".freeze
DEFAULT_NODE_BLOCK_NUMBER = 10
HAS_UNCLES_BLOCK_HASH = "0x252e4e972211b61466245ecb876c5025ce1c20bc2c4b07f23d377a14422a3f4e".freeze
HAS_UNCLES_BLOCK_NUMBER = 77

VCR.configure do |config|
  config.cassette_library_dir = "vcr_fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.default_cassette_options[:match_requests_on] = [:method, :path, :body]
end
DatabaseCleaner.strategy = :transaction

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    # Choose a test framework:
    with.test_framework :minitest

    with.library :rails
  end
end

if ENV["CI"] == "true"
  require "codecov"
  SimpleCov.formatter = SimpleCov::Formatter::Codecov
end

def prepare_inauthentic_node_data(node_tip_block_number = 10)
  Sidekiq::Testing.inline!
  CkbSync::Api.any_instance.stubs(:get_epoch_by_number).returns(
    CKB::Types::Epoch.new(
      epoch_reward: "250000000000",
      difficulty: "0x1000",
      length: "2000",
      number: "0",
      start_number: "0"
    )
  )
  local_tip_block_number = 0
  ((local_tip_block_number + 1)..node_tip_block_number).each do |number|
    VCR.use_cassette("genesis_block") do
      VCR.use_cassette("blocks/#{number}") do
        node_block = CkbSync::Api.instance.get_block_by_number(number)
        tx = node_block.transactions.first
        output = tx.outputs.first
        output.lock.instance_variable_set(:@args, ["0xb2e61ff569acf041b3c2c17724e2379c581eeac3"])
        output.lock.instance_variable_set(:@code_hash, ENV["CODE_HASH"])

        CkbSync::NodeDataProcessor.new.process_block(node_block)
        CkbSync::Api.any_instance.stubs(:get_cellbase_output_capacity_details).returns(
          CKB::Types::BlockReward.new(
            total: "100000000000",
            primary: "100000000000",
            secondary: "0",
            tx_fee: "10",
            proposal_reward: "10"
          )
        )
      end
    end
  end
end

def unpack_attribute(obj, attribute_name)
  value = obj.read_attribute(attribute_name)
  return if value.nil?

  attribute_before_type_cast = obj.attributes_before_type_cast[attribute_name]
  unescapted_attribute = ActiveRecord::Base.connection.unescape_bytea(attribute_before_type_cast)
  "#{ENV['DEFAULT_HASH_PREFIX']}#{unescapted_attribute.unpack1('H*')}" if unescapted_attribute.present?
end

def unpack_array_attribute(obj, attribute_name, array_size, hash_length)
  value = obj.attributes_before_type_cast[attribute_name]
  return if value.nil?

  value = ActiveRecord::Base.connection.unescape_bytea(value)
  template = Array.new(array_size || 0).reduce("") { |memo, _item| "#{memo}H#{hash_length}" }
  template = "S!#{template}"
  value.unpack(template.to_s).drop(1).map { |hash| "#{ENV['DEFAULT_HASH_PREFIX']}#{hash}" }.reject(&:blank?)
end

def format_node_block(node_block)
  header = node_block["header"]
  proposals = node_block["proposals"].presence
  header.merge({ proposals: proposals }.deep_stringify_keys)
end

def format_node_block_commit_transaction(commit_transaction)
  tx = commit_transaction.instance_values.reject { |key, _value| key.in?(%w(inputs outputs)) }
  tx["witnesses"] = tx["witnesses"].map(&:to_h).map(&:to_s)

  tx
end

def format_node_block_cell_output(cell_output)
  cell_output.select { |key, _value| key.in?(%w(capacity data)) }
end

def fake_node_block_with_type_script(node_block)
  output = node_block.transactions.first.outputs.first
  lock = output.lock
  output.instance_variable_set(:@type, lock)
end

def build_display_input_from_node_input(input)
  cell = input["previous_output"]["cell"]

  if cell.blank?
    { id: nil, from_cellbase: true, capacity: ENV["INITIAL_BLOCK_REWARD"].to_i, address_hash: nil }.stringify_keys
  else
    VCR.use_cassette("blocks/9") do
      previous_transaction_hash = cell["tx_hash"]
      previous_output_index = cell["index"].to_i
      commit_transaction = CkbSync::Api.instance.get_transaction(previous_transaction_hash)
      previous_output = commit_transaction["outputs"][previous_output_index]
      build_display_info_from_node_output(previous_output)
    end
  end
end

def fake_node_block(block_hash = DEFAULT_NODE_BLOCK_HASH, number = 10)
  json_block = "{\"header\":{\"dao\":\"0x01000000000000000000c16ff286230000a3a65e97fd03000057c138586f0000\",\"difficulty\":\"0x1000\",\"epoch\":\"0\",\"hash\":\"#{block_hash}\",\"number\":\"#{number}\",\"parent_hash\":\"0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3\",\"proposals_hash\":\"0x0000000000000000000000000000000000000000000000000000000000000000\",\"seal\":{\"nonce\":\"3241241169132127032\",\"proof\":\"0xd8010000850800001c0d00005c100000983b0000ae3b0000724300003e480000145f00008864000079770000d1780000\"},\"timestamp\":\"1557482351075\",\"transactions_root\":\"0xefb03572314fbb45aba0ef889373d3181117b253664de4dca0934e453b1e6bf3\",\"uncles_count\":0,\"uncles_hash\":\"0x0000000000000000000000000000000000000000000000000000000000000000\",\"version\":0,\"witnesses_root\":\"0x0000000000000000000000000000000000000000000000000000000000000000\"},\"proposals\":[],
    \"transactions\":[
      {\"deps\":[],\"hash\":\"0xefb03572314fbb45aba0ef889373d3181117b253664de4dca0934e453b1e6bf3\",\"inputs\":[{\"previous_output\":{\"block_hash\":null,\"cell\":{\"tx_hash\": \"0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3\", \"index\": \"0\"}},\"since\":\"0\"}],\"outputs\":[{\"capacity\":\"#{10**8 * 6}\",\"data\":\"0x\",\"lock\":{\"args\":[],\"code_hash\":\"0x0000000000000000000000000000000000000000000000000000000000000001\",\"hash_type\":\"Data\"},\"type\":null}],\"version\":0,\"witnesses\":[{\"data\":[\"0x54811ce986d5c3e57eaafab22cdd080e32209e39590e204a99b32935f835a13c\",\"0x3954acece65096bfa81258983ddb83915fc56bd8\"]}]},
      {\"deps\":[],\"hash\":\"0xefb03572314fbb45aba0ef889373d3181117b253664de4dca0934e453b1e6b23\",\"inputs\":[{\"previous_output\":{\"block_hash\":null,\"cell\":{\"tx_hash\": \"0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3\", \"index\": \"1\"}},\"since\":\"0\"}],\"outputs\":[{\"capacity\":\"#{10**8 * 5}\",\"data\":\"0x\",\"lock\":{\"args\":[],\"code_hash\":\"0x0000000000000000000000000000000000000000000000000000000000000001\",\"hash_type\":\"Data\"},\"type\":null}],\"version\":0,\"witnesses\":[]}
    ]
    ,\"uncles\":[]}"
  CKB::Types::Block.from_h(JSON.parse(json_block).deep_symbolize_keys)
end

def build_display_info_from_node_output(output)
  lock = output["lock"]
  lock_script = LockScript.find_by(args: lock["args"], code_hash: lock["code_hash"])
  cell_output = lock_script.cell_output
  { id: cell_output.id, capacity: cell_output.capacity.to_s, address_hash: cell_output.address_hash }.stringify_keys
end

def set_default_lock_params(node_block: block, args: ["0x#{SecureRandom.hex(20)}"], code_hash: ENV["CODE_HASH"])
  tx = node_block.transactions.first
  output = tx.outputs.first
  output.lock.instance_variable_set(:@args, args)
  output.lock.instance_variable_set(:@code_hash, code_hash)
end

def prepare_api_wrapper
  CkbSync::Api.any_instance.stubs(:get_cellbase_output_capacity_details).returns(
    CKB::Types::BlockReward.new(
      total: "100000000000",
      primary: "100000000000",
      secondary: "0",
      tx_fee: "0",
      proposal_reward: "0"
    )
  )
  VCR.use_cassette("genesis_block") do
    CkbSync::Api.instance
  end
end

def previous_cell_output(previous_output)
  cell = previous_output["cell"]

  raise ActiveRecord::RecordNotFound if cell.blank?

  tx_hash = cell["tx_hash"]
  output_index = cell["index"].to_i
  previous_transaction = CkbTransaction.find_by!(tx_hash: tx_hash)
  previous_transaction.cell_outputs.order(:id)[output_index]
end

def create_cell_output(trait_type: :with_full_transaction, status: "live")
  block = create(:block, :with_block_hash)
  create(:cell_output, trait_type, block: block, status: status)
end

def generate_miner_ranking_related_data(block_timestamp = 1560578500000)
  blocks = create_list(:block, 10, :with_block_hash)
  cellbases = []
  blocks.each do |block|
    cellbase = block.ckb_transactions.create(is_cellbase: true, block_timestamp: block_timestamp, block_number: 10)
    cellbases << cellbase
  end
  cellbases_part1 = cellbases[0..1]
  cellbases_part2 = cellbases[2..8]
  cellbases_part3 = cellbases[9..-1]
  address1 = create(:address, :with_lock_script)
  cellbases_part1.map { |cellbase| cellbase.cell_outputs.create!(block: cellbase.block, capacity: 10**8, address: address1, generated_by: cellbase) }
  address1.ckb_transactions << cellbases_part1
  address2 = create(:address, :with_lock_script)
  cellbases_part2.map { |cellbase| cellbase.cell_outputs.create!(block: cellbase.block, capacity: 10**8, address: address2, generated_by: cellbase) }
  address2.ckb_transactions << cellbases_part2
  address3 = create(:address, :with_lock_script)
  cellbases_part3.map { |cellbase| cellbase.cell_outputs.create!(block: cellbase.block, capacity: 10**8, address: address3, generated_by: cellbase) }
  address3.ckb_transactions << cellbases_part3

  return address1, address2, address3
end

def expected_ranking(address1, address2, address3)
  address1_block_ids = address1.ckb_transactions.where(is_cellbase: true).pluck("block_id")
  address2_block_ids = address2.ckb_transactions.where(is_cellbase: true).pluck("block_id")
  address3_block_ids = address3.ckb_transactions.where(is_cellbase: true).pluck("block_id")
  address1_blocks = Block.where(id: address1_block_ids)
  address2_blocks = Block.where(id: address2_block_ids)
  address3_blocks = Block.where(id: address3_block_ids)
  address1_base_rewards =
    address1_blocks.map { |block|
      base_reward(block.number, block.epoch)
    }.reduce(0, &:+)
  address2_base_rewards =
    address2_blocks.map { |block|
      base_reward(block.number, block.epoch)
    }.reduce(0, &:+)
  address3_base_rewards =
    address3_blocks.map { |block|
      base_reward(block.number, block.epoch)
    }.reduce(0, &:+)

  [
    { address_hash: address2.address_hash, lock_hash: address2.lock_hash, total_base_reward: address2_base_rewards },
    { address_hash: address1.address_hash, lock_hash: address1.lock_hash, total_base_reward: address1_base_rewards },
    { address_hash: address3.address_hash, lock_hash: address3.lock_hash, total_base_reward: address3_base_rewards }
  ]
end

module RequestHelpers
  def json
    JSON.parse(response.body)
  end

  def valid_get(uri, opts = {})
    params = {}
    params[:params] = opts[:params] || {}
    params[:headers] = { "Content-Type": "application/vnd.api+json", "Accept": "application/vnd.api+json" }
    send :get, uri, params
  end
end

module ActiveSupport
  class TestCase
    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    # fixtures :all
    include FactoryBot::Syntax::Methods
    include ::RequestHelpers

    # Add more helper methods to be used by all tests here...
    def before_setup
      super
      DatabaseCleaner.start
    end

    def after_setup
      prepare_api_wrapper
    end

    def after_teardown
      super
      DatabaseCleaner.clean
      Sidekiq::Worker.clear_all
      Rails.cache.clear
    end
  end
end
