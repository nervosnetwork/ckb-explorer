class LockScriptSerializer
  include FastJsonapi::ObjectSerializer
  cache_options enabled: true

  attributes :args, :code_hash, :hash_type
end
