class TokenTransfer < ApplicationRecord
  enum action: [:normal, :mint, :destruction]
  belongs_to :item, class_name: 'TokenItem'
  belongs_to :from, class_name: 'Address', optional: true
  belongs_to :to, class_name: 'Address', optional: true
  belongs_to :ckb_transaction, class_name: 'CkbTransaction', foreign_key: :transaction_id

  def as_json(options={})
    {
      id: id,
      from: from&.address_hash,
      to: to&.address_hash,
      item: item.as_json,
      action: action, 
      transaction: {
        tx_hash: ckb_transaction.tx_hash,
        block_number: ckb_transaction.block_number,
        block_timestamp: ckb_transaction.block_timestamp
      }
    }
  end
end

# == Schema Information
#
# Table name: token_transfers
#
#  id             :bigint           not null, primary key
#  item_id        :integer
#  from_id        :integer
#  to_id          :integer
#  transaction_id :integer
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  action         :integer
#
# Indexes
#
#  index_token_transfers_on_from_id         (from_id)
#  index_token_transfers_on_item_id         (item_id)
#  index_token_transfers_on_to_id           (to_id)
#  index_token_transfers_on_transaction_id  (transaction_id)
#
