class CellOutputSerializer
  include FastJsonapi::ObjectSerializer

  attributes :cell_type, :tx_hash, :cell_index, :type_hash, :data

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
    when "udt"
      object.udt_info
    when "cota_registry"
      object.cota_registry_info
    when "cota_regular"
      object.cota_regular_info
    when "m_nft_issuer", "m_nft_class", "m_nft_token"
      object.m_nft_info
    when "nrc_721_token", "nrc_721_factory"
      object.nrc_721_nft_info
    when "omiga_inscription_info", "omiga_inscription"
      object.omiga_inscription_info
    end
  end
end
