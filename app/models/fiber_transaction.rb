class FiberTransaction < ApplicationRecord
  belongs_to :fiber_channel
  belongs_to :fiber_peer
end

# == Schema Information
#
# Table name: fiber_transactions
#
#  id                 :bigint           not null, primary key
#  fiber_peer_id      :integer
#  fiber_channel_id   :integer
#  ckb_transaction_id :integer
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
