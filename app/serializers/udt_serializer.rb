class UdtSerializer
  include FastJsonapi::ObjectSerializer

  attributes :symbol, :full_name, :icon_file, :published, :description,
             :type_hash, :type_script, :issuer_address, :display_name, :uan

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

  attribute :mint_status, if: Proc.new { |record, _params|
    record.udt_type == "omiga_inscription"
  } do |object|
    object.omiga_inscription_info.mint_status
  end

  attribute :mint_limit, if: Proc.new { |record, _params|
    record.udt_type == "omiga_inscription"
  } do |object|
    object.omiga_inscription_info.mint_limit.to_s
  end

  attribute :expected_supply, if: Proc.new { |record, _params|
    record.udt_type == "omiga_inscription"
  } do |object|
    object.omiga_inscription_info.expected_supply.to_s
  end

  attribute :inscription_id, if: Proc.new { |record, _params|
    record.udt_type == "omiga_inscription"
  } do |object|
    object.omiga_inscription_info.args
  end
end
