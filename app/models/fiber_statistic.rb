class FiberStatistic < ApplicationRecord
  VALID_INDICATORS = %w(total_nodes total_channels total_liquidity created_at_unixtimestamp).freeze

  scope :filter_by_indicator, ->(indicator) {
    raise ArgumentError, "Invalid indicator" unless VALID_INDICATORS.include?(indicator.to_s)

    select(indicator, :created_at_unixtimestamp)
  }
end

# == Schema Information
#
# Table name: fiber_statistics
#
#  id                       :bigint           not null, primary key
#  total_nodes              :integer
#  total_channels           :integer
#  total_liquidity          :bigint
#  mean_value_locked        :bigint
#  mean_fee_rate            :integer
#  medium_value_locked      :bigint
#  medium_fee_rate          :integer
#  created_at_unixtimestamp :integer
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#
# Indexes
#
#  index_fiber_statistics_on_created_at_unixtimestamp  (created_at_unixtimestamp) UNIQUE
#
