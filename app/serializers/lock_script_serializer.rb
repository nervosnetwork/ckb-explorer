class LockScriptSerializer
  include FastJsonapi::ObjectSerializer

  attributes :args, :code_hash, :hash_type
end
