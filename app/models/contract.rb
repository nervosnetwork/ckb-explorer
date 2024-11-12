class Contract < ApplicationRecord
  has_many :referring_cells
  has_many :referring_cell_outputs, through: :referring_cells, source: :cell_output
  has_many :cell_deps_point_outputs, foreign_key: :deployed_cell_id, primary_key: :deployed_cell_id
  has_many :cell_dependencies, through: :cell_deps_point_outputs
  has_one :deployed_cell_output, foreign_key: :deployed_cell_output_id

  scope :filter_nil_hash_type, -> { where("hash_type IS NOT null and addresses_count != 0 and total_referring_cells_capacity != 0 and ckb_transactions_count != 0") }

  def self.query_script_ids(contracts)
    lock_script_ids = []
    type_script_ids = []
    contracts.each do |_contract|
      if is_lock_script
        lock_script_ids << LockScript.where(code_hash: [type_hash, data_hash]).pluck(:id)
      elsif is_type_script
        type_script_ids << TypeScript.where(code_hash: [type_hash, data_hash]).pluck(:id)
      end
    end
    { lock_script: lock_script_ids.flatten.uniq, type_script: type_script_ids.flatten.uniq }
  end
end

# == Schema Information
#
# Table name: contracts
#
#  id                             :bigint           not null, primary key
#  code_hash                      :binary
#  hash_type                      :string
#  deployed_args                  :string
#  role                           :string           default("type_script")
#  name                           :string
#  symbol                         :string
#  description                    :string
#  verified                       :boolean          default(FALSE)
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  deprecated                     :boolean
#  ckb_transactions_count         :decimal(30, )    default(0)
#  deployed_cells_count           :decimal(30, )    default(0)
#  referring_cells_count          :decimal(30, )    default(0)
#  total_deployed_cells_capacity  :decimal(30, )    default(0)
#  total_referring_cells_capacity :decimal(30, )    default(0)
#  addresses_count                :integer
#  h24_ckb_transactions_count     :integer
#  type_hash                      :binary
#  data_hash                      :binary
#  deployed_cell_output_id        :bigint
#  is_type_script                 :boolean
#  is_lock_script                 :boolean
#
# Indexes
#
#  index_contracts_on_code_hash   (code_hash)
#  index_contracts_on_deprecated  (deprecated)
#  index_contracts_on_hash_type   (hash_type)
#  index_contracts_on_name        (name)
#  index_contracts_on_role        (role)
#  index_contracts_on_symbol      (symbol)
#  index_contracts_on_verified    (verified)
#
