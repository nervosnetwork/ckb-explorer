class DaoDepositorSerializer
  include FastJsonapi::ObjectSerializer
  attributes :address_hash, :dao_deposit
end
