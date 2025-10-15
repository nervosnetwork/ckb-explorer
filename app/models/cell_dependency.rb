class CellDependency < ApplicationRecord
  belongs_to :ckb_transaction
  belongs_to :cell_output, foreign_key: "contract_cell_id", class_name: "CellOutput"
  has_many :cell_deps_out_points, foreign_key: :contract_cell_id, primary_key: :contract_cell_id, class_name: "CellDepsOutPoint"
  has_many :contracts, foreign_key: :contract_cell_id, primary_key: :contract_cell_id, class_name: "Contract"
  has_one :contract, -> { where(is_primary: true) }, foreign_key: :contract_cell_id, primary_key: :contract_cell_id, class_name: "Contract"

  enum :dep_type, %i[code dep_group]

  def to_raw
    script =
      if contract
        {
          name: contract.name,
          code_hash: contract.code_hash_hash_type[0],
          hash_type: contract.code_hash_hash_type[1],
          is_lock_script: contract.is_lock_script,
          is_type_script: contract.is_type_script,
        }
      else
        {
          name: nil,
          code_hash: nil,
          hash_type: nil,
          is_lock_script: false,
        }
      end
    {
      out_point: {
        tx_hash: cell_output.tx_hash,
        index: cell_output.cell_index,
      },
      dep_type: dep_type,
      script: script,
    }
  end
end

# == Schema Information
#
# Table name: cell_dependencies
#
#  id                 :bigint           not null, primary key
#  ckb_transaction_id :bigint           not null
#  dep_type           :integer
#  contract_cell_id   :bigint           not null
#  block_number       :bigint
#  tx_index           :integer
#  contract_analyzed  :boolean          default(FALSE)
#  is_used            :boolean          default(TRUE)
#
# Indexes
#
#  index_cell_dependencies_on_block_number_and_tx_index       (block_number,tx_index)
#  index_cell_dependencies_on_contract_analyzed               (contract_analyzed)
#  index_cell_dependencies_on_tx_id_and_cell_id_and_dep_type  (ckb_transaction_id,contract_cell_id,dep_type) UNIQUE
#  index_on_cell_dependencies_contract_cell_block_tx          (contract_cell_id,block_number DESC,tx_index DESC)
#
