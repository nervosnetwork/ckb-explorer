class FiberGraphNode < ApplicationRecord
  MAX_PAGINATES_PER = 100
  DEFAULT_PAGINATES_PER = 10
  paginates_per DEFAULT_PAGINATES_PER
  max_paginates_per MAX_PAGINATES_PER

  has_many :fiber_udt_cfg_infos, dependent: :delete_all

  def channel_links
    FiberGraphChannel.where(node1: node_id).or(FiberGraphChannel.where(node2: node_id)).
      where(closed_transaction_id: nil)
  end

  def udt_cfg_infos
    fiber_udt_cfg_infos.map(&:udt_info)
  end

  def total_capacity
    channel_links.sum(&:capacity)
  end

  def connected_node_ids
    node_ids = channel_links.pluck(:node1, :node2).flatten
    node_ids.uniq - [node_id]
  end

  def open_channels_count
    channel_links.count
  end
end

# == Schema Information
#
# Table name: fiber_graph_nodes
#
#  id                                 :bigint           not null, primary key
#  node_name                          :string
#  node_id                            :string
#  addresses                          :string           default([]), is an Array
#  timestamp                          :bigint
#  chain_hash                         :string
#  auto_accept_min_ckb_funding_amount :decimal(30, )
#  created_at                         :datetime         not null
#  updated_at                         :datetime         not null
#  peer_id                            :string
#
# Indexes
#
#  index_fiber_graph_nodes_on_node_id  (node_id) UNIQUE
#
