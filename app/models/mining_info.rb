class MiningInfo < ApplicationRecord
end

# == Schema Information
#
# Table name: mining_infos
#
#  id         :bigint           not null, primary key
#  address_id :bigint
#  block_id   :bigint
#  status     :integer          default(0)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
