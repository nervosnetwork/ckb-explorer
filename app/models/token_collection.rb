class TokenCollection < ApplicationRecord
  has_many :items, class_name: "TokenItem", foreign_key: :collection_id
  belongs_to :creator, class_name: "Address", optional: true
  belongs_to :cell, class_name: 'CellOutput', optional: true
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
      holders_count: items.distinct(:owner_id).count
    }
  end

  before_save :update_type_script

  def update_type_script
    self.type_script_id = cell.type_script_id if cell
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
