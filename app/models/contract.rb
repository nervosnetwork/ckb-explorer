class Contract < ApplicationRecord
  has_many :cell_deps_out_points, foreign_key: :deployed_cell_output_id, primary_key: :deployed_cell_output_id
  has_many :cell_dependencies, through: :cell_deps_out_points
  has_one :deployed_cell_output, foreign_key: :deployed_cell_output_id

  scope :active, -> { where("addresses_count != 0 and total_referring_cells_capacity != 0 and ckb_transactions_count != 0") }

  def self.query_script_ids(contracts)
    lock_script_ids = []
    type_script_ids = []
    contracts.each do |contract|
      binary_hashes = CkbUtils.hexes_to_bins_sql([contract.type_hash, contract.data_hash].compact)
      if contract.is_lock_script
        lock_script_ids << LockScript.where("code_hash IN (#{binary_hashes})").pluck(:id)
      elsif contract.is_type_script
        type_script_ids << TypeScript.where("code_hash IN (#{binary_hashes})").pluck(:id)
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
#  index_contracts_on_code_hash                (code_hash)
#  index_contracts_on_deployed_cell_output_id  (deployed_cell_output_id) UNIQUE
#  index_contracts_on_deprecated               (deprecated)
#  index_contracts_on_hash_type                (hash_type)
#  index_contracts_on_name                     (name)
#  index_contracts_on_role                     (role)
#  index_contracts_on_symbol                   (symbol)
#  index_contracts_on_verified                 (verified)
#
