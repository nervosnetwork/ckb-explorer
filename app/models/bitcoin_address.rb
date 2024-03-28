class BitcoinAddress < ApplicationRecord
  has_many :bitcoin_address_mappings
  has_many :ckb_addresses, class_name: "Address", through: :bitcoin_address_mappings
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
