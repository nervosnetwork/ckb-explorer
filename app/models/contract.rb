class Contract < ApplicationRecord
  has_many :scripts
  has_many :deployed_cells
  has_many :deployed_cell_outputs, through: :deployed_cells, source: :cell_output
  has_many :referring_cells
  has_many :cell_dependencies
  has_many :ckb_transactions, through: :cell_dependencies
end

# == Schema Information
#
# Table name: contracts
#
#  id            :bigint           not null, primary key
#  code_hash     :binary
#  hash_type     :string
#  deployed_args :string
#  role          :string           default("type_script")
#  name          :string
#  symbol        :string
#  description   :string
#  verified      :boolean          default(FALSE)
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  deprecated    :boolean
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
