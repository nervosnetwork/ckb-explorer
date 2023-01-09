class Script < ActiveRecord::Base
  self.abstract_class = true

  validates_presence_of :code_hash
  attribute :code_hash, :ckb_hash

  def to_node
    {
      args: args,
      code_hash: code_hash,
      hash_type: hash_type
    }
  end

  def as_json(options={})
    {
      args: args,
      code_hash: code_hash,
      hash_type: hash_type,
      script_hash: script_hash
    }
  end
end
