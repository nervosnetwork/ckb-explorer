class TokenCollectionSerializer
  include FastJsonapi::ObjectSerializer

  attributes :standard, :name, :description, :icon_url, :symbol, :sn
end
