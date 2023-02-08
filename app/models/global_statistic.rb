# this table is used for speeding up statistics
class GlobalStatistic < ApplicationRecord
  def self.reset_ckb_transactions_count
    ckb_transactions_count = CkbTransaction.count
    global_statistic = GlobalStatistic.find_or_create_by(name: 'ckb_transactions')
    global_statistic.update value: ckb_transactions_count
  end
end

# == Schema Information
#
# Table name: global_statistics
#
#  id         :bigint           not null, primary key
#  name       :string
#  value      :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
