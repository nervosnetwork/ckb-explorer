class TypeScript < ApplicationRecord
  has_many :cell_outputs

  belongs_to :cell_output, optional: true # will remove this later
  before_validation :generate_script_hash

  belongs_to :script, optional: true
  belongs_to :contract, optional: true, primary_key: "code_hash", foreign_key: "code_hash"

  validates_presence_of :code_hash
  attribute :code_hash, :ckb_hash

  def self.process(sdk_type)
    type_hash = sdk_type.compute_hash
    # contract = Contract.create_or_find_by(code_hash: lock.code_hash)
    # script = Script
    create_with(
      script_hash: type_hash
    ).create_or_find_by(
      code_hash: sdk_type.code_hash,
      hash_type: sdk_type.hash_type,
      args: sdk_type.args
    )
  end

  def to_node
    {
      args: args,
      code_hash: code_hash,
      hash_type: hash_type
    }
  end

  def as_json(options = {})
    {
      args: args,
      code_hash: code_hash,
      hash_type: hash_type,
      script_hash: script_hash
    }
  end

  def ckb_transactions
    CkbTransaction.where(id: cell_outputs.pluck(&:ckb_transaction_id))
  end

  def short_code_hash
    code_hash[-4..]
  end

  def generate_script_hash
    self.hash_type ||= "type"
    self.script_hash ||= CKB::Types::Script.new(**to_node).compute_hash rescue nil
  end

  # @return [Integer] Byte
  def calculate_bytesize
    bytesize = 1
    bytesize += CKB::Utils.hex_to_bin(code_hash).bytesize if code_hash
    bytesize += CKB::Utils.hex_to_bin(args).bytesize if args

    bytesize
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
#  script_id      :bigint
#
# Indexes
#
#  index_type_scripts_on_cell_output_id                    (cell_output_id)
#  index_type_scripts_on_code_hash_and_hash_type_and_args  (code_hash,hash_type,args)
#  index_type_scripts_on_script_hash                       (script_hash) USING hash
#  index_type_scripts_on_script_id                         (script_id)
#
