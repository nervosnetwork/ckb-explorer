class BitcoinVin < ApplicationRecord
  belongs_to :previous_bitcoin_vout, class_name: "BitcoinVout"
  belongs_to :ckb_transaction
  belongs_to :cell_input
end

# == Schema Information
#
# Table name: bitcoin_vins
#
#  id                       :bigint           not null, primary key
#  previous_bitcoin_vout_id :bigint
#  ckb_transaction_id       :bigint
#  cell_input_id            :bigint
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#
# Indexes
#
#  index_bitcoin_vins_on_ckb_transaction_id                    (ckb_transaction_id)
#  index_bitcoin_vins_on_ckb_transaction_id_and_cell_input_id  (ckb_transaction_id,cell_input_id) UNIQUE
#
