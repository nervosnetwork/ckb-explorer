class TokenItem < ApplicationRecord
  enum status: { normal: 1, burnt: 0 }

  belongs_to :collection, class_name: "TokenCollection"
  belongs_to :owner, class_name: "Address"
  belongs_to :cell, class_name: "CellOutput", optional: true
  belongs_to :type_script, optional: true
  has_many :transfers, class_name: "TokenTransfer", foreign_key: :item_id

  validates :token_id, uniqueness: { scope: :collection_id }

  before_save :update_type_script

  def update_type_script
    self.type_script_id = cell&.type_script_id
  end

  def as_json(options = {})
    {
      id: id,
      token_id: token_id.to_s,
      owner: owner.address_hash,
      cell: {
        status: cell&.status,
        tx_hash: cell&.tx_hash,
        cell_index: cell&.cell_index
      },
      type_script: type_script&.as_json,
      name: name,
      metadata_url: metadata_url,
      icon_url: icon_url,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  def self.fix_nrc721_token_id
    TokenItem.where(collection: { standard: "nrc721" }).find_each do |_item|
      token_id = token.token_id.to_s(16)
      token.token_id = token_id[2..-1].hex
      token.save
    end
  end
end

# == Schema Information
#
# Table name: token_items
#
#  id             :bigint           not null, primary key
#  collection_id  :integer
#  token_id       :decimal(80, )
#  name           :string
#  icon_url       :string
#  owner_id       :integer
#  metadata_url   :string
#  cell_id        :integer
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  type_script_id :integer
#  status         :integer          default("normal")
#
# Indexes
#
#  index_token_items_on_cell_id                     (cell_id)
#  index_token_items_on_collection_id_and_token_id  (collection_id,token_id) UNIQUE
#  index_token_items_on_owner_id                    (owner_id)
#  index_token_items_on_type_script_id              (type_script_id)
#
