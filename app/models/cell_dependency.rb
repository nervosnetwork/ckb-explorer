# this is the ReferringCell model, parse from `cell_deps` of transaction raw hash
class CellDependency < ApplicationRecord
  belongs_to :ckb_transaction
  belongs_to :cell_output, foreign_key: "contract_cell_id", class_name: "CellOutput"
  belongs_to :cell_deps_out_point, foreign_key: :contract_cell_id, primary_key: :contract_cell_id, optional: true

  enum :dep_type, %i[code dep_group]

  def self.refresh_implicit
    connection.execute "SELECT update_cell_dependencies_implicit();"
  end

  def to_raw
    {
      out_point: {
        tx_hash: cell_output.tx_hash,
        index: cell_output.cell_index,
      },
      dep_type:,
    }
  end
end

# == Schema Information
#
# Table name: cell_dependencies
#
#  id                 :bigint           not null, primary key
#  contract_id        :bigint
#  ckb_transaction_id :bigint           not null
#  dep_type           :integer
#  contract_cell_id   :bigint           not null
#  script_id          :bigint
#  implicit           :boolean          default(TRUE), not null
#  block_number       :bigint
#  tx_index           :integer
#  contract_analyzed  :boolean          default(FALSE)
#
# Indexes
#
#  index_cell_dependencies_on_block_number_and_tx_index       (block_number,tx_index)
#  index_cell_dependencies_on_contract_analyzed               (contract_analyzed)
#  index_cell_dependencies_on_contract_id                     (contract_id)
#  index_cell_dependencies_on_script_id                       (script_id)
#  index_cell_dependencies_on_tx_id_and_cell_id_and_dep_type  (ckb_transaction_id,contract_cell_id,dep_type) UNIQUE
#  index_on_cell_dependencies_contract_cell_block_tx          (contract_cell_id,block_number DESC,tx_index DESC)
#
