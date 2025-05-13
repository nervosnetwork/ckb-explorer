class TypeScriptSerializer
  include FastJsonapi::ObjectSerializer

  attributes :args, :code_hash, :hash_type, :script_hash

  attribute :verified_script_name do |object|
    object.verified_script&.name
  end
end
