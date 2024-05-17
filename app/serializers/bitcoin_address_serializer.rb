class BitcoinAddressSerializer
  include FastJsonapi::ObjectSerializer

  attributes :address_hash
end
