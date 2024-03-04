class BitcoinVout < ApplicationRecord
  belongs_to :cell_output_id, optional: true
  belongs_to :bitcoin_transaction, dependent: :delete
  belongs_to :bitcoin_address, optional: true

  def commitment
    script_pubkey = Bitcoin::Script.parse_from_payload(hex.htb)
    return unless script_pubkey.op_return?

    script_pubkey.op_return_data.bth
  end
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
