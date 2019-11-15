class DaoDepositorSerializer
  include FastJsonapi::ObjectSerializer
  attributes :address_hash
  attribute :dao_deposit do |object|
    object.dao_deposit.to_s
  end
end
