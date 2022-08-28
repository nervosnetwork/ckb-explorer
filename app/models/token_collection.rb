class TokenCollection < ApplicationRecord
  has_many :items, class_name: "TokenItem", foreign_key: :collection_id
  belongs_to :creator, class_name: "Address", optional: true
  belongs_to :cell, class_name: 'CellOutput', optional: true
  belongs_to :type_script, optional: true
  has_many :transfers, class_name: "TokenTransfer", through: :items

  def as_json(options = {})
    {
      id: id,
      standard: standard,
      name: name,
      description: description,
      icon_url: icon_url,
      creator: creator&.address_hash || "",
      items_count: items.count,
      holders_count: items.distinct(:owner_id).count,
      type_script: type_script&.as_json
    }
  end

  before_save :update_type_script

  def update_type_script
    self.type_script_id = cell.type_script_id if cell
  end

  def self.update_cell
    where(cell_id: nil).where.not(type_script_id: nil).find_each do |tc|
      c = tc.type_script.cell_outputs.last
      tc.cell_id = c.id
      tc.creator_id = c.address_id

      tc.save
    end
  end
end

# == Schema Information
#
# Table name: token_collections
#
#  id             :bigint           not null, primary key
#  standard       :string
#  name           :string
#  description    :text
#  creator_id     :integer
#  icon_url       :string
#  items_count    :integer
#  holders_count  :integer
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  symbol         :string
#  cell_id        :integer
#  verified       :boolean          default(FALSE)
#  type_script_id :integer
#
# Indexes
#
#  index_token_collections_on_cell_id         (cell_id)
#  index_token_collections_on_type_script_id  (type_script_id)
#
