class RgbppAssetsStatistic < ApplicationRecord
  enum :network, %i[global ckb btc]
  enum :indicator, %i[ft_count dob_count holders_count transactions_count]
end

# == Schema Information
#
# Table name: rgbpp_assets_statistics
#
#  id                       :bigint           not null, primary key
#  indicator                :integer          not null
#  value                    :decimal(40, )    default(0)
#  network                  :integer          default("global")
#  created_at_unixtimestamp :integer
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#
# Indexes
#
#  index_on_indicator_and_network_and_created_at_unixtimestamp  (indicator,network,created_at_unixtimestamp) UNIQUE
#
