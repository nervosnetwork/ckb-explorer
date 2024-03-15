class Contract < ApplicationRecord
  has_many :scripts
  has_many :deployed_cells
  has_many :deployed_cell_outputs, through: :deployed_cells, source: :cell_output
  has_many :referring_cells
  has_many :referring_cell_outputs, through: :referring_cells, source: :cell_output
  has_many :cell_dependencies
  has_many :ckb_transactions, through: :cell_dependencies

  scope :filter_nil_hash_type, -> { where("hash_type IS NOT null and addresses_count != 0 and total_referring_cells_capacity != 0 and ckb_transactions_count != 0") }

  def self.create_initial_data
    Contract.transaction do
      Script.find_each do |script|
        contract = Contract.find_by code_hash: script.script_hash
        if contract.blank?
          contract = Contract.create code_hash: script.script_hash
        end
        script.update contract_id: contract.id
      end
    end
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
