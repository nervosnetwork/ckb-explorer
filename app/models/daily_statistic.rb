class DailyStatistic < ApplicationRecord
  VALID_INDICATORS = %w(transactions_count addresses_count total_dao_deposit)
end

# == Schema Information
#
# Table name: daily_statistics
#
#  id                       :bigint           not null, primary key
#  transactions_count       :integer          default(0)
#  addresses_count          :integer          default(0)
#  total_dao_deposit        :decimal(30, )    default(0)
#  block_timestamp          :decimal(30, )
#  created_at_unixtimestamp :integer
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#
