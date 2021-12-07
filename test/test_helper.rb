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
DEFAULT_NODE_BLOCK_HASH = "0x845d51afabf510408d1f1e75f187cb6cc7abb0e3448e9eb854645b09fb48654e".freeze
DEFAULT_NODE_BLOCK_NUMBER = 12
HAS_UNCLES_BLOCK_HASH = "0xb55406ca549b13cc21599f82e41d1e743166870028c1b29a24c62cd41e8d47b6".freeze
HAS_UNCLES_BLOCK_NUMBER = 13

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

def prepare_node_data(node_tip_block_number = 30)
  Sidekiq::Testing.inline!
  GenerateStatisticsDataWorker.any_instance.stubs(:perform).returns(true)
  CkbSync::Api.any_instance.stubs(:get_tip_block_number).returns(node_tip_block_number + 1)
  CkbSync::Api.any_instance.stubs(:get_epoch_by_number).returns(
    CKB::Types::Epoch.new(
      compact_target: "0x1000",
      length: "0x07d0",
      number: "0x0",
      start_number: "0x0"
    )
  )
  local_tip_block_number = 0
  ((local_tip_block_number)..node_tip_block_number).each do |number|
    VCR.use_cassette("genesis_block") do
      VCR.use_cassette("blocks/#{number}", record: :new_episodes) do
        node_block = CkbSync::Api.instance.get_block_by_number(number)
        CkbSync::Api.any_instance.stubs(:get_block_economic_state).returns(
          OpenStruct.new(miner_reward: CKB::Types::MinerReward.new(
            primary: "0x174876e800",
            secondary: "0xa",
            committed: "0xa",
            proposal: "0xa"
          ))
        )
        CkbSync::NewNodeDataProcessor.new.process_block(node_block)
        CkbSync::Api.any_instance.stubs(:get_cellbase_output_capacity_details).returns(
          CKB::Types::BlockReward.new(
            total: "0x174876e800",
            primary: "0x174876e800",
            secondary: "0xa",
            tx_fee: "0xa",
            proposal_reward: "0xa"
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
  header["compact_target"] = header["compact_target"].hex
  header["number"] = header["number"].hex
  header["timestamp"] = header["timestamp"].hex
  header["version"] = header["version"].hex
  header["nonce"] = header["nonce"].hex
  header["epoch"] = "0x#{CKB::Utils.to_hex(header['epoch']).split(//).last(6).join('')}".hex
  proposals = node_block["proposals"].presence
  header.merge({ proposals: proposals }.deep_stringify_keys)
end

def format_node_block_commit_transaction(commit_transaction)
  tx = commit_transaction.instance_values.reject { |key, _value| key.in?(%w(inputs outputs outputs_data)) }
  tx["witnesses"] = JSON.parse(tx["witnesses"].to_json)

  tx
end

def format_node_block_cell_output(cell_output)
  output = cell_output.select { |key, _value| key == "capacity" }
  output["capacity"] = output["capacity"].hex

  output
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

def fake_node_block(block_hash = DEFAULT_NODE_BLOCK_HASH, number = "0xc")
  CkbSync::Api.any_instance.stubs(:get_tip_block_number).returns(DEFAULT_NODE_BLOCK_NUMBER + 1)
  json_block = "{\"header\":{\"dao\":\"0x01000000000000000000c16ff286230000a3a65e97fd03000057c138586f0000\",\"compact_target\":\"0x1000\",\"epoch\":\"0x0\",\"hash\":\"#{block_hash}\",\"number\":\"#{number}\",\"parent_hash\":\"0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3\",\"proposals_hash\":\"0x0000000000000000000000000000000000000000000000000000000000000000\",\"nonce\":\"0x2cfb33aba57e0338\",\"timestamp\":\"0x16aa12ea9e3\",\"transactions_root\":\"0xefb03572314fbb45aba0ef889373d3181117b253664de4dca0934e453b1e6bf3\",\"extra_hash\":\"0x0000000000000000000000000000000000000000000000000000000000000000\",\"version\":\"0x0\"},\"proposals\":[],
    \"transactions\":[
      {\"header_deps\":[],\"cell_deps\":[],\"outputs_data\":[\"0x\"],\"hash\":\"0xefb03572314fbb45aba0ef889373d3181117b253664de4dca0934e453b1e6bf3\",\"inputs\":[{\"previous_output\":{\"tx_hash\": \"0x0000000000000000000000000000000000000000000000000000000000000000\", \"index\": \"0x0\"},\"since\":\"0x0\"}],\"outputs\":[{\"capacity\":\"0x23c34600\",\"data\":\"0x\",\"lock\":{\"args\":\"0xb2e61ff569acf041b3c2c17724e2379c581eeac3\",\"code_hash\":\"0x1d107ddec56ec77b79c41cd10b35a3b47434c93a604ecb8e8e73e7372fe1a794\",\"hash_type\":\"data\"},\"type\":null}],\"version\":\"0x0\",\"witnesses\":[\"0x5d0000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000003954acece65096bfa81258983ddb83915fc56bd804000000123456780000000000000000\"]},
      {\"header_deps\":[],\"cell_deps\":[],\"outputs_data\":[\"0x\"],\"hash\":\"0xefb03572314fbb45aba0ef889373d3181117b253664de4dca0934e453b1e6bf2\",\"inputs\":[{\"previous_output\":{\"tx_hash\": \"0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3\", \"index\": \"0x2\"},\"since\":\"0x0\"}],\"outputs\":[{\"capacity\":\"0x23c34600\",\"data\":\"0x\",\"lock\":{\"args\":\"0xb2e61ff569acf041b3c2c17724e2379c581eeac3\",\"code_hash\":\"0x1d107ddec56ec77b79c41cd10b35a3b47434c93a604ecb8e8e73e7372fe1a794\",\"hash_type\":\"data\"},\"type\":null}],\"version\":\"0x0\",\"witnesses\":[\"0x5d0000000c00000055000000490000001000000030000000310000009bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce801140000003954acece65096bfa81258983ddb83915fc56bd804000000123456780000000000000000\"]},
      {\"header_deps\":[],\"cell_deps\":[],\"outputs_data\":[\"0x\"],\"hash\":\"0xefb03572314fbb45aba0ef889373d3181117b253664de4dca0934e453b1e6b23\",\"inputs\":[{\"previous_output\":{\"tx_hash\": \"0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3\", \"index\": \"0x1\"},\"since\":\"0x0\"}],\"outputs\":[{\"capacity\":\"0x1dcd6500\",\"data\":\"0x\",\"lock\":{\"args\":\"0xb2e61ff569acf041b3c2c17724e2379c581eeac3\",\"code_hash\":\"0x1d107ddec56ec77b79c41cd10b35a3b47434c93a604ecb8e8e73e7372fe1a794\",\"hash_type\":\"data\"},\"type\":null}],\"version\":\"0x0\",\"witnesses\":[\"0x\"]}
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

def prepare_api_wrapper
  SecureRandom.stubs(:uuid).returns(1)
  CkbSync::Api.any_instance.stubs(:get_cellbase_output_capacity_details).returns(
    CKB::Types::BlockReward.new(
      total: "0x174876e800",
      primary: "0x174876e800",
      secondary: "0x0",
      tx_fee: "0x0",
      proposal_reward: "0x0"
    )
  )
  CkbSync::Api.any_instance.stubs(:get_block_economic_state).returns(
    OpenStruct.new(miner_reward: CKB::Types::MinerReward.new(
      primary: "0x174876e800",
      secondary: "0xa",
      committed: "0xa",
      proposal: "0xa"
    ))
  )
  VCR.use_cassette("genesis_block") do
    CkbSync::Api.instance
  end
end

def previous_cell_output(previous_output)
  raise ActiveRecord::RecordNotFound if previous_output["tx_hash"] == CellOutput::SYSTEM_TX_HASH

  tx_hash = previous_output["tx_hash"]
  output_index = previous_output["index"].to_i
  previous_transaction = CkbTransaction.find_by!(tx_hash: tx_hash)
  previous_transaction.cell_outputs.order(:id)[output_index]
end

def create_cell_output(trait_type: :with_full_transaction, status: "live")
  block = create(:block, :with_block_hash)
  create(:cell_output, trait_type, block: block, status: status)
end

def generate_miner_ranking_related_data(block_timestamp = 1560578500000)
  blocks = create_list(:block, 10, :with_block_hash, number: 12)
  cellbases = []
  blocks.each_with_index do |block, index|
    block.update(number: block.number + index)
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

def fake_dao_deposit_transaction(dao_cell_count, address)
  block = create(:block, :with_block_hash)
  DaoContract.default_contract.update(ckb_transactions_count: dao_cell_count)
  address.update(dao_transactions_count: dao_cell_count)
  dao_cell_count.times do |number|
    if number % 2 == 0
      ckb_transaction1 = create(:ckb_transaction, tx_hash: "0x#{SecureRandom.hex(32)}", block: block, address: address, dao_address_ids: [address.id], contained_address_ids: [address.id], tags: ["dao"])
      create(:cell_output, ckb_transaction: ckb_transaction1, cell_index: number, tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", generated_by: ckb_transaction1, block: block, capacity: 10**8 * 1000, cell_type: "nervos_dao_deposit", address: address)
    else
      ckb_transaction2 = create(:ckb_transaction, tx_hash: "0x#{SecureRandom.hex(32)}", block: block, address: address, dao_address_ids: [address.id], contained_address_ids: [address.id], tags: ["dao"])
      create(:cell_output, ckb_transaction: ckb_transaction2, cell_index: number, tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", generated_by: ckb_transaction2, block: block, capacity: 10**8 * 1000, cell_type: "nervos_dao_deposit", address: address)
    end
  end
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
      CKB::Types::Block.any_instance.stubs(:serialized_size_without_uncle_proposals).returns(400)
    end

    def after_teardown
      super
      DatabaseCleaner.clean
      Sidekiq::Worker.clear_all
      Rails.cache.clear
    end
  end
end
