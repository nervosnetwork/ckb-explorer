class TokenCollection < ApplicationRecord
  has_many :items, class_name: 'TokenItem', foreign_key: :collection_id
  belongs_to :creator, class_name: 'Address', optional: true
  has_many :transfers, class_name: 'TokenTransfer', through: :items
  
end

# == Schema Information
#
# Table name: token_collections
#
#  id            :bigint           not null, primary key
#  standard      :string
#  name          :string
#  description   :text
#  creator_id    :integer
#  icon_url      :string
#  items_count   :integer
#  holders_count :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
