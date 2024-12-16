class RgbppHourlyStatistic < ApplicationRecord
end

# == Schema Information
#
# Table name: rgbpp_hourly_statistics
#
#  id                       :bigint           not null, primary key
#  xudt_count               :integer          default(0)
#  dob_count                :integer          default(0)
#  created_at_unixtimestamp :integer
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#
# Indexes
#
#  index_rgbpp_hourly_statistics_on_created_at_unixtimestamp  (created_at_unixtimestamp) UNIQUE
#
