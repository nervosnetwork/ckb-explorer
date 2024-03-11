class BitcoinAddress < ApplicationRecord
  has_many :bitcoin_vouts

  def ckb_address
    bitcoin_vouts.take.ckb_address
  end
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
