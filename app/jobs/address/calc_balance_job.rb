class Address::CalcBalanceJob < ApplicationJob
  def perform(address_id)
    address =  address_id.is_a?(Address) ? address_id : Address.find(address_id)

  end
end
