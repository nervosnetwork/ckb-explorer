class BitcoinVout < ApplicationRecord
  enum status: { bound: 0, unbound: 1, binding: 2, normal: 3 }

  belongs_to :bitcoin_transaction, dependent: :delete
  belongs_to :consumed_by, class_name: "BitcoinTransaction", optional: true
  belongs_to :bitcoin_address, optional: true
  belongs_to :ckb_transaction, optional: true
  belongs_to :cell_output, optional: true, touch: true
  belongs_to :ckb_address, class_name: "Address", foreign_key: "address_id", optional: true

  scope :without_op_return, -> { where(op_return: false) }

  def commitment
    return unless op_return?

    script_pub_key = Bitcoin::Script.parse_from_payload(data.htb)
    script_pub_key.op_return_data.bth
  end
end

# == Schema Information
#
# Table name: bitcoin_vouts
#
#  id                     :bigint           not null, primary key
#  bitcoin_transaction_id :bigint
#  bitcoin_address_id     :bigint
#  data                   :binary
#  index                  :integer
#  asm                    :text
#  op_return              :boolean          default(FALSE)
#  ckb_transaction_id     :bigint
#  cell_output_id         :bigint
#  address_id             :bigint
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  status                 :integer          default("bound")
#  consumed_by_id         :bigint
#
# Indexes
#
#  index_bitcoin_vouts_on_bitcoin_address_id  (bitcoin_address_id)
#  index_bitcoin_vouts_on_ckb_transaction_id  (ckb_transaction_id)
#  index_bitcoin_vouts_on_consumed_by_id      (consumed_by_id)
#  index_bitcoin_vouts_on_status              (status)
#  index_vouts_uniqueness                     (bitcoin_transaction_id,index,cell_output_id) UNIQUE
#
