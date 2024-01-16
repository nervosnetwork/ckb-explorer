class OmigaInscriptionInfoSerializer
  include FastJsonapi::ObjectSerializer

  attributes :code_hash, :hash_type, :args, :name, :symbol, :udt_hash,
             :mint_status

  attribute :decimal do |object|
    object.decimal.to_s
  end

  attribute :expected_supply do |object|
    object.expected_supply.to_s
  end

  attribute :mint_limit do |object|
    object.mint_limit.to_s
  end
end
