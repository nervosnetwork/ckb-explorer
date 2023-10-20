class Portfolio < ApplicationRecord
  belongs_to :user
  belongs_to :address
end

# == Schema Information
#
# Table name: portfolios
#
#  id         :bigint           not null, primary key
#  user_id    :bigint
#  address_id :bigint
#
# Indexes
#
#  index_portfolios_on_user_id_and_address_id  (user_id,address_id) UNIQUE
#
