class Address::CalcBalanceJob < ApplicationJob
  def perform(address_id)
    address =  case address_id
    when Address
      address_id
    when Number
      Address.find(address_id)
    when /\Ack.*\z/
      Address.find_by address_hash: address_id
    when /\A0x.*\z/
      Address.find_by lock_hash: address_id
    end

    address.cal_balance!
    address.save
  end
end
