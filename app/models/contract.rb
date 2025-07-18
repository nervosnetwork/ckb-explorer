class Contract < ApplicationRecord
  ZERO_LOCK_HASH = "0x0000000000000000000000000000000000000000000000000000000000000000".freeze

  has_many :cell_deps_out_points, foreign_key: :deployed_cell_output_id, primary_key: :deployed_cell_output_id
  has_many :cell_dependencies, through: :cell_deps_out_points
  has_one :ssri_contract
  belongs_to :deployed_cell_output, class_name: "CellOutput"
  belongs_to :contract_cell, class_name: "CellOutput", optional: true

  scope :active, -> { where("addresses_count != 0 and total_referring_cells_capacity != 0 and ckb_transactions_count != 0") }
  scope :live_verified, -> { joins(:deployed_cell_output).where(verified: true, deployed_cell_output: { status: :live }) }
  scope :primary, -> { where(is_primary: true) }

  enum dep_type: { code: 0, dep_group: 1 }

  def self.referring_cells_query(contracts)
    lock_script_hashes = []
    type_script_hashes = []
    contracts.each do |contract|
      binary_hashes = CkbUtils.hexes_to_bins_sql([contract.type_hash, contract.data_hash].compact)
      if contract.is_lock_script
        lock_script_hashes << binary_hashes
      elsif contract.is_type_script
        type_script_hashes << binary_hashes
      end
    end
    scope = CellOutput.live
    if lock_script_hashes.length > 0
      scope = scope.joins(:lock_script).where("lock_scripts.code_hash IN (#{lock_script_hashes.join(',')})")
    end
    if type_script_hashes.length > 0
      scope = scope.joins(:type_script).where("type_scripts.code_hash IN (#{type_script_hashes.join(',')})")
    end
    scope
  end

  def code_hash_hash_type
    if type_hash
      [type_hash, "type"]
    else
      [data_hash, hash_type]
    end
  end
end

# == Schema Information
#
# Table name: contracts
#
#  id                             :bigint           not null, primary key
#  hash_type                      :string
#  deployed_args                  :string
#  name                           :string
#  description                    :string
#  verified                       :boolean          default(FALSE)
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  deprecated                     :boolean
#  ckb_transactions_count         :decimal(30, )    default(0)
#  referring_cells_count          :decimal(30, )    default(0)
#  total_referring_cells_capacity :decimal(30, )    default(0)
#  addresses_count                :integer
#  h24_ckb_transactions_count     :integer
#  type_hash                      :binary
#  data_hash                      :binary
#  deployed_cell_output_id        :bigint
#  is_type_script                 :boolean
#  is_lock_script                 :boolean
#  rfc                            :string
#  source_url                     :string
#  dep_type                       :integer
#  website                        :string
#  deployed_block_timestamp       :decimal(20, )
#  contract_cell_id               :bigint
#  is_primary                     :boolean
#  is_zero_lock                   :boolean
#
# Indexes
#
#  index_contracts_on_deployed_cell_output_id  (deployed_cell_output_id) UNIQUE
#  index_contracts_on_deprecated               (deprecated)
#  index_contracts_on_hash_type                (hash_type)
#  index_contracts_on_name                     (name)
#  index_contracts_on_verified                 (verified)
#
