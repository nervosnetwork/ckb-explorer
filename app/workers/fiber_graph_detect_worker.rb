class FiberGraphDetectWorker
  include Sidekiq::Worker
  sidekiq_options queue: "fiber"

  attr_accessor :graph_node_ids, :graph_channel_outpoint, :fiber_node_url

  def perform
    @graph_node_ids = []
    @graph_channel_outpoints = []
    @fiber_node_url = ENV.fetch("FIBER_NODE_URL", nil)

    ApplicationRecord.transaction do
      # sync graph nodes and channels
      ["nodes", "channels"].each { fetch_graph_infos(_1) }
      # generate fiber account books
      build_fiber_account_books
      # purge outdated graph nodes
      FiberGraphNode.where.not(node_id: @graph_node_ids).destroy_all
      # purge outdated graph channels
      FiberGraphChannel.where.not(channel_outpoint: @graph_channel_outpoints).destroy_all
      # generate statistic
      compute_statistic
    end
  end

  private

  def fetch_graph_infos(data_type)
    return if @fiber_node_url.blank?

    cursor = nil

    loop do
      break if cursor == "0x"

      next_cursor = send("fetch_#{data_type}", cursor)
      break if next_cursor.nil? || next_cursor == cursor

      cursor = next_cursor
    end
  end

  def fetch_nodes(last_cursor)
    data = rpc.graph_nodes(@fiber_node_url, { limit: "0x64", after: last_cursor })
    data.dig("result", "nodes").each { upsert_node_with_cfg_info(_1) }
    data.dig("result", "last_cursor")
  end

  def fetch_channels(last_cursor)
    data = rpc.graph_channels(@fiber_node_url, { limit: "0x64", after: last_cursor })
    channel_attributes = data.dig("result", "channels").map { build_channel_attributes(_1) }.compact
    FiberGraphChannel.upsert_all(channel_attributes, unique_by: %i[channel_outpoint]) if channel_attributes.any?
    data.dig("result", "last_cursor")
  end

  def upsert_node_with_cfg_info(node)
    node_attributes = {
      node_name: node["node_name"],
      node_id: node["node_id"],
      addresses: node["addresses"],
      timestamp: node["timestamp"].to_i(16),
      chain_hash: node["chain_hash"],
      peer_id: extract_peer_id(node["addresses"]),
      auto_accept_min_ckb_funding_amount: node["auto_accept_min_ckb_funding_amount"],
      deleted_at: nil,
    }
    @graph_node_ids << node_attributes[:node_id]
    fiber_graph_node = FiberGraphNode.upsert(node_attributes, unique_by: %i[node_id], returning: %i[id])

    return unless fiber_graph_node && node["udt_cfg_infos"].present?

    cfg_info_attributes = node["udt_cfg_infos"].filter_map do |info|
      udt = Udt.find_by(info["script"].symbolize_keys)
      next unless udt

      {
        fiber_graph_node_id: fiber_graph_node[0]["id"],
        udt_id: udt.id,
        auto_accept_amount: info["auto_accept_amount"].to_i(16),
        deleted_at: nil,
      }
    end

    FiberUdtCfgInfo.upsert_all(cfg_info_attributes, unique_by: %i[fiber_graph_node_id udt_id]) if cfg_info_attributes.any?
  end

  def build_channel_attributes(channel)
    if (udt_type_script = channel["udt_type_script"]).present?
      udt = Udt.find_by(udt_type_script.symbolize_keys)
    end

    channel_outpoint = channel["channel_outpoint"]
    tx_hash = channel_outpoint[0..65]
    cell_index = [channel_outpoint[66..]].pack("H*").unpack1("V")
    open_transaction = CkbTransaction.find_by(tx_hash:)
    cell_output = open_transaction.outputs.find_by(cell_index:)
    @graph_channel_outpoints << channel_outpoint

    channel_attributes = {
      channel_outpoint:,
      node1: channel["node1"],
      node2: channel["node2"],
      created_timestamp: channel["created_timestamp"].to_i(16),
      capacity: channel["capacity"].to_i(16),
      update_info_of_node1: {},
      update_info_of_node2: {},
      chain_hash: channel["chain_hash"],
      open_transaction_id: open_transaction.id,
      address_id: cell_output.address_id,
      cell_output_id: cell_output.id,
      udt_id: udt&.id,
      deleted_at: nil,
    }

    if (info_of_node1 = channel["update_info_of_node1"]).present?
      channel_attributes[:update_info_of_node1] = {
        timestamp: info_of_node1["timestamp"].to_i(16),
        enabled: info_of_node1["enabled"],
        outbound_liquidity: info_of_node1["outbound_liquidity"],
        tlc_expiry_delta: info_of_node1["tlc_expiry_delta"].to_i(16),
        tlc_minimum_value: info_of_node1["tlc_minimum_value"].to_i(16),
        fee_rate: info_of_node1["fee_rate"].to_i(16),
      }
    end

    if (info_of_node2 = channel["update_info_of_node2"]).present?
      channel_attributes[:update_info_of_node2] = {
        timestamp: info_of_node2["timestamp"].to_i(16),
        enabled: info_of_node2["enabled"],
        outbound_liquidity: info_of_node2["outbound_liquidity"],
        tlc_expiry_delta: info_of_node2["tlc_expiry_delta"].to_i(16),
        tlc_minimum_value: info_of_node2["tlc_minimum_value"].to_i(16),
        fee_rate: info_of_node2["fee_rate"].to_i(16),
      }
    end

    channel_attributes
  end

  def extract_peer_id(addresses)
    return nil if addresses.blank?

    parts = addresses[0].split("/")
    p2p_index = parts.index("p2p") || parts.index("ipfs")

    if p2p_index && parts.length > p2p_index + 1
      parts[p2p_index + 1]
    end
  end

  def build_fiber_account_books
    account_book_attributes = []
    FiberGraphChannel.where.not(deleted_at: nil).find_each do |channel|
      open_transaction = channel.open_transaction
      open_transaction.account_books.each do |account_book|
        account_book_attributes << {
          fiber_graph_channel_id: channel.id,
          ckb_transaction_id: open_transaction.id,
          address_id: account_book.address_id,
        }
      end
    end

    FiberAccountBook.upsert_all(account_book_attributes, unique_by: %i[address_id ckb_transaction_id]) if account_book_attributes.any?
  end

  def compute_statistic
    created_at_unixtimestamp = Time.now.beginning_of_day.to_i
    statistic = FiberStatistic.find_or_create_by!(created_at_unixtimestamp:)
    statistic.reset_all!
  end

  def rpc
    @rpc ||= FiberCoordinator.instance
  end
end
