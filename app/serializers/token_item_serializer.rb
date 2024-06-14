class TokenItemSerializer
  include FastJsonapi::ObjectSerializer

  attributes :name, :icon_url, :metadata_url, :icon_url, :status

  attribute :token_id do |object|
    object.token_id.to_s
  end

  attribute :token_collection do |object|
    {
      standard: object.collection.standard,
      name: object.collection.name,
      description: object.collection.description,
      icon_url: object.collection.icon_url,
      symbol: object.collection.symbol,
      sn: object.collection.sn,
    }
  end
end
