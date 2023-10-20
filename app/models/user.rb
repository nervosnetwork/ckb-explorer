class User < ApplicationRecord
  include Uuidable

  has_one :portfolio_statistic
  has_many :portfolios
end

# == Schema Information
#
# Table name: users
#
#  id         :bigint           not null, primary key
#  uuid       :string(36)
#  identifier :string
#  name       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_users_on_identifier  (identifier) UNIQUE
#  index_users_on_uuid        (uuid) UNIQUE
#
