class MiningInfo < ApplicationRecord
  enum status: { mined: 0, issued: 1, reverted: 2 }

  belongs_to :block
  belongs_to :address
end

# == Schema Information
#
# Table name: mining_infos
#
#  id           :bigint           not null, primary key
#  address_id   :bigint
#  block_id     :bigint
#  block_number :decimal(30, )
#  status       :integer          default("mined")
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_mining_infos_on_block_id      (block_id)
#  index_mining_infos_on_block_number  (block_number)
#
