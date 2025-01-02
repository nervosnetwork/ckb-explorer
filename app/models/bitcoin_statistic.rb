class BitcoinStatistic < ApplicationRecord
  enum :network, %i[ckb btc]
  default_scope { order(timestamp: :asc) }
end

# == Schema Information
#
# Table name: bitcoin_statistics
#
#  id                 :bigint           not null, primary key
#  timestamp          :bigint
#  transactions_count :integer          default(0)
#  addresses_count    :integer          default(0)
#
# Indexes
#
#  index_bitcoin_statistics_on_timestamp  (timestamp)
#
