class BitcoinVout < ApplicationRecord
  belongs_to :bitcoin_transaction, dependent: :delete
  belongs_to :bitcoin_address, optional: true
  belongs_to :ckb_transaction, optional: true
  belongs_to :cell_output, optional: true
  belongs_to :ckb_address, class_name: "Address", optional: true

  def commitment
    return unless op_return?

    script_pubkey = Bitcoin::Script.parse_from_payload(hex.htb)
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
#  op_return              :boolean          default(FALSE)
#  ckb_transaction_id     :bigint
#  cell_output_id         :bigint
#  address_id             :bigint
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_bitcoin_vouts_on_bitcoin_address_id                (bitcoin_address_id)
#  index_bitcoin_vouts_on_bitcoin_transaction_id_and_index  (bitcoin_transaction_id,index) UNIQUE
#  index_bitcoin_vouts_on_ckb_transaction_id                (ckb_transaction_id)
#
