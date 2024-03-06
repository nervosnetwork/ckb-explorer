class BitcoinVin < ApplicationRecord
  belongs_to :bitcoin_transaction
  belongs_to :previous_previous_bitcoin_vout, class_name: "BitcoinVout", optional: true
  belongs_to :ckb_transaction
end

# == Schema Information
#
# Table name: bitcoin_vins
#
#  id                       :bigint           not null, primary key
#  previous_bitcoin_vout_id :bigint
#  bitcoin_transaction_id   :bigint
#  ckb_transaction_id       :bigint
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#
# Indexes
#
#  index_bitcoin_vins_on_ckb_transaction_id  (ckb_transaction_id)
#  prev_bitcoin_vout                         (bitcoin_transaction_id,previous_bitcoin_vout_id) UNIQUE
#
