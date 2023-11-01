class Portfolio < ApplicationRecord
  belongs_to :user
  belongs_to :address

  def self.sync_addresses(user, address_hashes)
    transaction do
      address_hashes.each do |address_hash|
        address = Address.find_or_create_by_address_hash(address_hash)
        user.portfolios.find_or_create_by(address: address)
      end
    end
  end
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
