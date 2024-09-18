class FiberPeer < ApplicationRecord
  has_many :fiber_channels, dependent: :destroy, foreign_key: :peer_id
  has_many :fiber_transactions
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
