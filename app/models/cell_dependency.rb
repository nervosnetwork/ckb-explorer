# this is the ReferringCell model, parse from `cell_deps` of transaction raw hash
class CellDependency < ApplicationRecord
  belongs_to :contract, optional: true
  belongs_to :ckb_transaction
  belongs_to :script
  belongs_to :cell_output, foreign_key: "contract_cell_id", class_name: "CellOutput"
  enum :dep_type, [:code, :dep_group]
  scope :implicit, -> { where(implicit: true) }
  scope :explicit, -> { where(implicit: false) }

  def self.refresh_implicit
    connection.execute "SELECT update_cell_dependencies_implicit();"
  end

  def to_raw
    {
      out_point: {
        tx_hash: cell_output.tx_hash,
        index: cell_output.cell_index
      },
      dep_type: dep_type
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
#
# Indexes
#
#  cell_deps_tx_cell_idx                        (ckb_transaction_id,contract_cell_id) UNIQUE
#  index_cell_dependencies_on_contract_cell_id  (contract_cell_id)
#  index_cell_dependencies_on_contract_id       (contract_id)
#  index_cell_dependencies_on_script_id         (script_id)
#
