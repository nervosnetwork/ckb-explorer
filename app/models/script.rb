class Script < ActiveRecord::Base
  has_many :lock_scripts
  has_many :type_scripts
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

# == Schema Information
#
# Table name: scripts
#
#  id          :bigint           not null, primary key
#  args        :string
#  script_hash :string
#  is_contract :boolean          default(FALSE)
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
