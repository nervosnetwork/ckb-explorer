class CellOutputDataSerializer
  include FastJsonapi::ObjectSerializer
  cache_options enabled: true
  set_type :data

  attributes :data
end
