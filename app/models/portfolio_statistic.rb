class PortfolioStatistic < ApplicationRecord
  belongs_to :user
end

# == Schema Information
#
# Table name: portfolio_statistics
#
#  id                     :bigint           not null, primary key
#  user_id                :bigint
#  capacity               :decimal(30, )    default(0)
#  occupied_capacity      :decimal(30, )    default(0)
#  dao_deposit            :decimal(30, )    default(0)
#  interest               :decimal(30, )    default(0)
#  unclaimed_compensation :decimal(30, )    default(0)
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_portfolio_statistics_on_user_id  (user_id) UNIQUE
#
