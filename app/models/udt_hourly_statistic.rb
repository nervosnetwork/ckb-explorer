class UdtHourlyStatistic < ApplicationRecord
  belongs_to :udt

  def percentage_change(attribute)
    yesterday = previous_stat(udt_id, 1)
    day_before_yesterday = previous_stat(udt_id, 2)

    return nil unless yesterday && day_before_yesterday

    yesterday_value = yesterday.public_send(attribute)
    day_before_yesterday_value = day_before_yesterday.public_send(attribute)

    return nil if day_before_yesterday_value.zero?

    ((yesterday_value - day_before_yesterday_value).to_f / day_before_yesterday_value * 100).round(2)
  end

  def previous_stat(udt_id, days_ago)
    timestamp = (Time.current - days_ago.days).beginning_of_day.to_i
    self.class.find_by(udt_id:, created_at_unixtimestamp: timestamp)
  end
end

# == Schema Information
#
# Table name: udt_hourly_statistics
#
#  id                       :bigint           not null, primary key
#  udt_id                   :bigint           not null
#  ckb_transactions_count   :integer          default(0)
#  amount                   :decimal(40, )    default(0)
#  holders_count            :integer          default(0)
#  created_at_unixtimestamp :integer
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#
# Indexes
#
#  index_on_udt_id_and_unixtimestamp  (udt_id,created_at_unixtimestamp) UNIQUE
#
