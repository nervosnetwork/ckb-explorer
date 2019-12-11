class EpochStatistic < ApplicationRecord
  VALID_INDICATORS = %w(difficulty uncle_rate).freeze
end

# == Schema Information
#
# Table name: epoch_statistics
#
#  id           :bigint           not null, primary key
#  difficulty   :string
#  uncle_rate   :string
#  epoch_number :decimal(30, )
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_epoch_statistics_on_epoch_number  (epoch_number) UNIQUE
#
