class FiberGraphChannel < ApplicationRecord
  MAX_PAGINATES_PER = 100
  DEFAULT_PAGINATES_PER = 10
  paginates_per DEFAULT_PAGINATES_PER
  max_paginates_per MAX_PAGINATES_PER
end

# == Schema Information
#
# Table name: fiber_graph_channels
#
#  id                      :bigint           not null, primary key
#  channel_outpoint        :string
#  funding_tx_block_number :bigint
#  funding_tx_index        :integer
#  node1                   :string
#  node2                   :string
#  last_updated_timestamp  :bigint
#  created_timestamp       :bigint
#  node1_to_node2_fee_rate :decimal(30, )    default(0)
#  node2_to_node1_fee_rate :decimal(30, )    default(0)
#  capacity                :decimal(64, 2)   default(0.0)
#  chain_hash              :string
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#
# Indexes
#
#  index_fiber_graph_channels_on_channel_outpoint  (channel_outpoint) UNIQUE
#
