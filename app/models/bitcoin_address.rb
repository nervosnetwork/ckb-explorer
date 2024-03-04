class BitcoinAddress < ApplicationRecord
  has_many :bitcoin_vouts
end

# == Schema Information
#
# Table name: bitcoin_addresses
#
#  id           :bigint           not null, primary key
#  address_hash :binary           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
