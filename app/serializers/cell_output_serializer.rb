class CellOutputSerializer
  include FastJsonapi::ObjectSerializer

  attributes :cell_type, :tx_hash, :cell_index, :type_hash, :data

  attribute :block_number do |object|
    object.block.number.to_s
  end

  attribute :capacity do |object|
    object.capacity.to_s
  end

  attribute :occupied_capacity do |object|
    object.occupied_capacity.to_s
  end

  attribute :block_timestamp do |object|
    object.block_timestamp.to_s
  end

  attribute :type_script do |object|
    object&.type_script&.to_node
  end

  attribute :lock_script do |object|
    object.lock_script.to_node
  end

  attribute :extra_info do |object|
    case object.cell_type
    when "normal"
      { type: "ckb", capacity: object.capacity.to_s }
    when "udt"
      object.udt_info.merge!(type: "udt")
    when "cota_registry"
      object.cota_registry_info.merge!(type: "cota")
    when "cota_regular"
      object.cota_regular_info.merge!(type: "cota")
    when "m_nft_issuer", "m_nft_class", "m_nft_token"
      object.m_nft_info.merge!(type: "m_nft")
    when "nrc_721_token", "nrc_721_factory"
      object.nrc_721_nft_info.merge!(type: "nrc_721")
    when "omiga_inscription_info", "omiga_inscription"
      object.omiga_inscription_info.merge!(type: "omiga_inscription")
    end
  end
end
