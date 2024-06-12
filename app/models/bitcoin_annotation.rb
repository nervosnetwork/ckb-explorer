class BitcoinAnnotation < ApplicationRecord
  belongs_to :ckb_transaction

  enum :leap_direction, %i[in withinBTC leapoutBTC]
  enum :transfer_step, %i[isomorphic unlock]
end

# == Schema Information
#
# Table name: bitcoin_annotations
#
#  id                 :bigint           not null, primary key
#  ckb_transaction_id :bigint
#  leap_direction     :integer
#  transfer_step      :integer
#  tags               :string           default([]), is an Array
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
# Indexes
#
#  index_bitcoin_annotations_on_ckb_transaction_id  (ckb_transaction_id) UNIQUE
#
