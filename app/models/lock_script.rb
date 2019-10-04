class LockScript < ApplicationRecord
  belongs_to :address

  validates_presence_of :code_hash

  attribute :code_hash, :ckb_hash

  def cell_output
    CellOutput.find(cell_output_id)
  end

  def to_node_lock
    {
      args: args,
      code_hash: code_hash,
      hash_type: hash_type
    }
  end
end

# == Schema Information
#
# Table name: lock_scripts
#
#  id             :bigint           not null, primary key
#  args           :string
#  code_hash      :binary
#  cell_output_id :bigint
#  address_id     :bigint
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  hash_type      :string
#
# Indexes
#
#  index_lock_scripts_on_address_id      (address_id)
#  index_lock_scripts_on_cell_output_id  (cell_output_id)
#
