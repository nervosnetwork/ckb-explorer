class BitcoinVout < ApplicationRecord
  belongs_to :cell_output_id
  belongs_to :bitcoin_transaction
  belongs_to :bitcoin_address, optional: true
end

# == Schema Information
#
# Table name: bitcoin_vouts
#
#  id                     :bigint           not null, primary key
#  bitcoin_transaction_id :bigint
#  bitcoin_address_id     :bigint
#  hex                    :binary
#  index                  :integer
#  asm                    :text
#  cell_output_id         :bigint
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_bitcoin_vouts_on_bitcoin_address_id                (bitcoin_address_id)
#  index_bitcoin_vouts_on_bitcoin_transaction_id_and_index  (bitcoin_transaction_id,index) UNIQUE
#
