class FiberGraphNode < ApplicationRecord
  MAX_PAGINATES_PER = 100
  DEFAULT_PAGINATES_PER = 10
  paginates_per DEFAULT_PAGINATES_PER
  max_paginates_per MAX_PAGINATES_PER
end

# == Schema Information
#
# Table name: fiber_graph_nodes
#
#  id                                 :bigint           not null, primary key
#  alias                              :string
#  node_id                            :string
#  addresses                          :string           default([]), is an Array
#  timestamp                          :bigint
#  chain_hash                         :string
#  auto_accept_min_ckb_funding_amount :decimal(30, )
#  created_at                         :datetime         not null
#  updated_at                         :datetime         not null
#
# Indexes
#
#  index_fiber_graph_nodes_on_node_id  (node_id) UNIQUE
#
