class TokenItem < ApplicationRecord
  belongs_to :collection, class_name: 'TokenCollection'
  belongs_to :owner, class_name: 'Address'
  belongs_to :cell, class_name: 'CellOutput', optional: true
  has_many :transfers, class_name: 'TokenTransfer', foreign_key: :item_id

  validates :token_id, uniqueness:{scope: :collection_id}
end

# == Schema Information
#
# Table name: token_items
#
#  id            :bigint           not null, primary key
#  collection_id :integer
#  token_id      :string
#  name          :string
#  icon_url      :string
#  owner_id      :integer
#  metadata_url  :string
#  cell_id       :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_token_items_on_cell_id                     (cell_id)
#  index_token_items_on_collection_id_and_token_id  (collection_id,token_id) UNIQUE
#  index_token_items_on_owner_id                    (owner_id)
#
