class FiberGraphDetectWorker
  include Sidekiq::Worker
  sidekiq_options queue: "fiber"

  attr_accessor :graph_node_ids, :graph_channel_outpoint

  def perform
    @graph_node_ids = []
    @graph_channel_outpoints = []

    # sync graph nodes and channels
    ["nodes", "channels"].each { fetch_graph_infos(_1) }
    # purge outdated graph nodes
    FiberGraphNode.where.not(node_id: @graph_node_ids).delete_all
    # purge outdated graph channels
    FiberGraphChannel.where.not(channel_outpoint: @graph_channel_outpoints).delete_all

    # check channel is closed
    FiberGraphChannel.open_channels.each do |channel|
      funding_cell = channel.funding_cell
      if funding_cell.consumed_by
        channel.update(closed_transaction_id: funding_cell.consumed_by_id)
      end
    end
  end

  private

  def fetch_graph_infos(data_type)
    return if ENV["FIBER_NODE_URL"].blank?

    cursor = nil

    loop do
      break if cursor == "0x"

      next_cursor = send("fetch_#{data_type}", cursor)
      break if next_cursor.nil? || next_cursor == cursor

      cursor = next_cursor
    end
  end

  def fetch_nodes(last_cursor)
    data = rpc.graph_nodes(ENV["FIBER_NODE_URL"], { limit: "0x64", after: last_cursor })
    ApplicationRecord.transaction { data.dig("result", "nodes").each { upsert_node_with_cfg_info(_1) } }
    data.dig("result", "last_cursor")
  rescue StandardError => e
    Rails.logger.error("Error fetching nodes: #{e.message}")
    nil
  end

  def fetch_channels(last_cursor)
    data = rpc.graph_channels(ENV["FIBER_NODE_URL"], { limit: "0x64", after: last_cursor })
    channel_attributes = data.dig("result", "channels").map { build_channel_attributes(_1) }.compact
    FiberGraphChannel.upsert_all(channel_attributes, unique_by: %i[channel_outpoint]) if channel_attributes.any?
    data.dig("result", "last_cursor")
  rescue StandardError => e
    Rails.logger.error("Error fetching channels: #{e.message}")
    nil
  end

  def upsert_node_with_cfg_info(node)
    node_attributes = {
      alias: node["alias"],
      node_id: node["node_id"],
      addresses: node["addresses"],
      timestamp: node["timestamp"].to_i(16),
      chain_hash: node["chain_hash"],
      peer_id: extract_peer_id(node["addresses"]),
      auto_accept_min_ckb_funding_amount: node["auto_accept_min_ckb_funding_amount"],
    }
    @graph_node_ids << node_attributes[:node_id]
    fiber_graph_node = FiberGraphNode.upsert(node_attributes, unique_by: %i[node_id], returning: %i[id])

    return unless fiber_graph_node && node["udt_cfg_infos"].present?

    cfg_info_attributes = node["udt_cfg_infos"].map do |info|
      udt = Udt.find_by(info["script"].symbolize_keys)
      next unless udt

      {
        fiber_graph_node_id: fiber_graph_node[0]["id"],
        udt_id: udt.id,
        auto_accept_amount: info["auto_accept_amount"].to_i(16),
      }
    end.compact

    FiberUdtCfgInfo.upsert_all(cfg_info_attributes, unique_by: %i[fiber_graph_node_id udt_id]) if cfg_info_attributes.any?
  end

  def build_channel_attributes(channel)
    if (udt_type_script = channel["udt_type_script"]).present?
      udt = Udt.find_by(udt_type_script.symbolize_keys)
    end

    channel_outpoint = channel["channel_outpoint"]
    open_transaction = CkbTransaction.find_by(tx_hash: channel_outpoint[0..65])
    @graph_channel_outpoints << channel_outpoint

    {
      channel_outpoint:,
      funding_tx_block_number: channel["funding_tx_block_number"].to_i(16),
      funding_tx_index: channel["funding_tx_index"].to_i(16),
      node1: channel["node1"],
      node2: channel["node2"],
      last_updated_timestamp: channel["last_updated_timestamp"].to_i(16),
      created_timestamp: channel["created_timestamp"],
      node1_to_node2_fee_rate: channel["node1_to_node2_fee_rate"].to_i(16),
      node2_to_node1_fee_rate: channel["node2_to_node1_fee_rate"].to_i(16),
      capacity: channel["capacity"].to_i(16),
      chain_hash: channel["chain_hash"],
      open_transaction_id: open_transaction&.id,
      udt_id: udt&.id,
    }
  end

  def extract_peer_id(addresses)
    return nil if addresses.blank?

    parts = addresses[0].split("/")
    p2p_index = parts.index("p2p") || parts.index("ipfs")

    if p2p_index && parts.length > p2p_index + 1
      parts[p2p_index + 1]
    end
  end

  def rpc
    @rpc ||= FiberCoordinator.instance
  end
end
