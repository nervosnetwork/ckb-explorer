class FiberGraphDetectWorker
  include Sidekiq::Worker
  sidekiq_options queue: "fiber"

  def perform
    ["nodes", "channels"].each { fetch_graph_infos(_1) }
  end

  private

  def fetch_graph_infos(data_type)
    cursor = nil

    loop do
      break if cursor == "0x"

      next_cursor = send("fetch_#{data_type}", cursor)
      break if next_cursor.nil? || next_cursor == cursor

      cursor = next_cursor
    end
  end

  def fetch_nodes(last_cursor)
    return if ENV["FIBER_NODE_URL"].blank?

    data = rpc.graph_nodes(ENV["FIBER_NODE_URL"], { limit: "0x100", after: last_cursor })
    node_attributes = data["result"]["nodes"].map do |node|
      {
        alias: node["alias"],
        node_id: node["node_id"],
        addresses: node["addresses"],
        timestamp: node["timestamp"].to_i(16),
        chain_hash: node["chain_hash"],
        auto_accept_min_ckb_funding_amount: node["auto_accept_min_ckb_funding_amount"],
      }
    end

    FiberGraphNode.upsert_all(node_attributes, unique_by: %i[node_id]) if node_attributes.any?

    data["result"]["last_cursor"]
  rescue StandardError => e
    Rails.logger.error("Error fetching nodes: #{e.message}")
    nil
  end

  def fetch_channels(last_cursor)
    return if ENV["FIBER_NODE_URL"].blank?

    data = rpc.graph_channels(ENV["FIBER_NODE_URL"], { limit: "0x100", after: last_cursor })
    channel_attributes = data["result"]["channels"].map do |channel|
      {
        channel_outpoint: channel["channel_outpoint"],
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
      }
    end

    FiberGraphChannel.upsert_all(channel_attributes, unique_by: %i[channel_outpoint]) if channel_attributes.any?

    data["result"]["last_cursor"]
  rescue StandardError => e
    Rails.logger.error("Error fetching channels: #{e.message}")
    nil
  end

  def rpc
    @rpc ||= FiberCoordinator.instance
  end
end
