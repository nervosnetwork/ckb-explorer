class UdtSerializer
  include FastJsonapi::ObjectSerializer

  attributes :symbol, :full_name, :icon_file, :published, :description, :type_hash, :type_script, :issuer_address, :display_name, :uan

  attribute :total_amount do |object|
    object.total_amount.to_s
  end
  attribute :addresses_count do |object|
    object.addresses_count.to_s
  end
  attribute :decimal do |object|
    object.decimal.to_s
  end
  attribute :h24_ckb_transactions_count do |object|
    object.h24_ckb_transactions_count.to_s
  end
  attributes :created_at do |object|
    object.block_timestamp.to_s
  end
end
