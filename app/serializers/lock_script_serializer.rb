class LockScriptSerializer
  include FastJsonapi::ObjectSerializer

  attributes :args, :code_hash, :hash_type

  attribute :verified_script_name do |object|
    object.verified_script&.name
  end
end
