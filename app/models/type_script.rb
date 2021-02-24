class TypeScript < ApplicationRecord
  has_many :cell_outputs
  belongs_to :cell_output, optional: true # will remove this later

  validates_presence_of :code_hash

  attribute :code_hash, :ckb_hash

  def to_node_type
    {
      args: args,
      code_hash: code_hash,
      hash_type: hash_type
    }
  end

  def short_code_hash
    code_hash[-4..]
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
#  lock_hash      :string
#
# Indexes
#
#  index_type_scripts_on_cell_output_id  (cell_output_id)
#
