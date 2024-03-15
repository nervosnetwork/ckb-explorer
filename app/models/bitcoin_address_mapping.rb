class BitcoinAddressMapping < ApplicationRecord
  belongs_to :ckb_address, class_name: "Address", optional: true
  belongs_to :bitcoin_address
end

# == Schema Information
#
# Table name: bitcoin_address_mappings
#
#  id                 :bigint           not null, primary key
#  bitcoin_address_id :bigint
#  ckb_address_id     :bigint
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
# Indexes
#
#  idex_bitcon_addresses_on_mapping  (bitcoin_address_id,ckb_address_id) UNIQUE
#
