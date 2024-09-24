class FiberPeer < ApplicationRecord
  MAX_PAGINATES_PER = 100
  DEFAULT_PAGINATES_PER = 10
  paginates_per DEFAULT_PAGINATES_PER
  max_paginates_per MAX_PAGINATES_PER

  has_many :fiber_channels, dependent: :destroy
  # has_many :fiber_transactions

  validates :peer_id, presence: true, uniqueness: true

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
#  rpc_listening_addr      :string           default([]), is an Array
#  first_channel_opened_at :datetime
#  last_channel_updated_at :datetime
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#
