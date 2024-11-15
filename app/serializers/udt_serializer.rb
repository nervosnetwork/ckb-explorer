class UdtSerializer
  include FastJsonapi::ObjectSerializer

  attributes :symbol, :full_name, :icon_file, :published, :description,
             :type_hash, :type_script, :issuer_address, :udt_type, :operator_website

  attribute :email do |object|
    object.email&.sub(/\A(..)(.*)@(.*)(..)\z/) do
      $1 + "*" * $2.length + "@" + "*" * $3.length + $4
    end
  end

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
  attribute :created_at do |object|
    object.block_timestamp.to_s
  end
  attribute :holders_count do |object|
    object.holders_count.to_s
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

  attribute :inscription_info_id, if: Proc.new { |record, _params|
    record.udt_type == "omiga_inscription"
  } do |object|
    object.omiga_inscription_info.args
  end

  attribute :info_type_hash, if: Proc.new { |record, _params|
    record.udt_type == "omiga_inscription"
  } do |object|
    object.omiga_inscription_info.type_hash
  end

  attribute :pre_udt_hash, if: Proc.new { |record, _params|
    record.udt_type == "omiga_inscription"
  } do |object|
    object.omiga_inscription_info.pre_udt_hash
  end

  attribute :is_repeated_symbol, if: Proc.new { |record, _params|
    record.udt_type == "omiga_inscription"
  } do |object|
    object.omiga_inscription_info.is_repeated_symbol
  end

  attribute :xudt_tags, if: Proc.new { |record, _params|
    record.udt_type.in?(["xudt", "xudt_compatible"]) && record.published
  } do |object|
    object.xudt_tag&.tags
  end
end
