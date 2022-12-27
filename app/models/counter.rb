# this table is just used for counting the rows
# e.g.
# name: ckb_transactions
# value: 10014390
# see: db/migrate/20221227013538_create_counts.rb
class Counter < ApplicationRecord
end

# == Schema Information
#
# Table name: counters
#
#  id         :bigint           not null, primary key
#  name       :string
#  value      :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
