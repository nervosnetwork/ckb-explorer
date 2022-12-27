class TypeScript < ApplicationRecord
  has_many :cell_outputs
  has_many :ckb_transactions

  belongs_to :cell_output, optional: true # will remove this later
  validates_presence_of :code_hash

  attribute :code_hash, :ckb_hash

  before_validation :generate_script_hash

  def ckb_transactions
    CkbTransaction.where(:id => cell_outputs.map(&:id))
  end

  def to_node_type
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

  def short_code_hash
    code_hash[-4..]
  end

  def generate_script_hash
    self.hash_type ||= 'type'
    self.script_hash ||= CKB::Types::Script.new(**to_node_type).compute_hash rescue nil
  end
end

# == Schema Information
#
# Table name: type_scripts
#
#  id             :bigint           not null, primary key
#  args           :string
#  code_hash      :binary
#  cell_output_id :bigint
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  hash_type      :string
#  script_hash    :string
#
# Indexes
#
#  index_type_scripts_on_cell_output_id                    (cell_output_id)
#  index_type_scripts_on_code_hash_and_hash_type_and_args  (code_hash,hash_type,args)
#  index_type_scripts_on_script_hash                       (script_hash)
#
