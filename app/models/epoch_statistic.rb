class EpochStatistic < ApplicationRecord
  VALID_INDICATORS = %w(difficulty uncle_rate)
end

# == Schema Information
#
# Table name: epoch_statistics
#
#  id           :bigint           not null, primary key
#  difficulty   :string
#  uncle_rate   :string
#  epoch_number :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
