class DaoDepositorSerializer
  include FastJsonapi::ObjectSerializer
  attributes :address_hash
  attribute :dao_deposit do |object|
    object.dao_deposit.to_s
  end
  attribute :average_deposit_time do |object|
    object.average_deposit_time&.truncate(3).to_s
  end
end
