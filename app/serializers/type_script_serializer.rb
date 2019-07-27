class TypeScriptSerializer
  include FastJsonapi::ObjectSerializer

  attributes :args, :code_hash, :hash_type
end
