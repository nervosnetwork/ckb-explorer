class FiberChannel < ApplicationRecord
  belongs_to :fiber_peer, class_name: "FiberPeer", foreign_key: :peer_id, primary_key: :peer_id, inverse_of: :fiber_channels
  # has_many :fiber_transactions
end

# == Schema Information
#
# Table name: fiber_channels
#
#  id                   :bigint           not null, primary key
#  peer_id              :string
#  channel_id           :string
#  state_name           :string
#  state_flags          :string           default([]), is an Array
#  local_balance        :decimal(64, 2)   default(0.0)
#  sent_tlc_balance     :decimal(64, 2)   default(0.0)
#  remote_balance       :decimal(64, 2)   default(0.0)
#  received_tlc_balance :decimal(64, 2)   default(0.0)
#  shutdown_at          :datetime
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
# Indexes
#
#  index_fiber_channels_on_peer_id_and_channel_id  (peer_id,channel_id) UNIQUE
#
