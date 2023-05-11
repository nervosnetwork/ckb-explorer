# this table is used for speeding up statistics
class GlobalStatistic < ApplicationRecord
  def self.reset_ckb_transactions_count
    ckb_transactions_count = CkbTransaction.count
    global_statistic = GlobalStatistic.find_or_create_by(name: "ckb_transactions")
    global_statistic.update value: ckb_transactions_count
  end

  # direct increment value using upsert
  # @param name [String] the name of statistic field
  # @param delta [Integer] the value to increment
  def self.increment(name, delta = 1)
    connection.execute <<~SQL
      INSERT INTO global_statistics (name, value, created_at, updated_at)
      VALUES (#{connection.quote name}, 1, now(), now())
      ON CONFLICT (name) DO UPDATE SET value = global_statistics.value + #{delta}
    SQL
  end
end

# == Schema Information
#
# Table name: global_statistics
#
#  id                                                              :bigint           not null, primary key
#  name                                                            :string
#  value                                                           :bigint
#  created_at                                                      :datetime         not null
#  updated_at                                                      :datetime         not null
#  comment                                                         :string
#  #<ActiveRecord::ConnectionAdapters::PostgreSQL::TableDefinition :string
#
# Indexes
#
#  index_global_statistics_on_name  (name) UNIQUE
#
