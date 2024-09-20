class FiberPeer < ApplicationRecord
  has_many :fiber_channels, foreign_key: :peer_id, primary_key: :peer_id, inverse_of: :fiber_peer, dependent: :destroy
  # has_many :fiber_transactions

  def total_local_balance
    fiber_channels.where(state_name: "CHANNEL_READY").sum(:local_balance)
  end

  def channels_count
    fiber_channels.where(state_name: "CHANNEL_READY").count
  end
end

# == Schema Information
#
# Table name: fiber_peers
#
#  id                      :bigint           not null, primary key
#  name                    :string
#  peer_id                 :string
#  rpc_listening_addr      :string
#  first_channel_opened_at :datetime
#  last_channel_updated_at :datetime
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#
