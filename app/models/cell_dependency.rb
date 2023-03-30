# this is the ReferringCell model
class CellDependency < ActiveRecord::Base
  belongs_to :contract, optional: true
  belongs_to :ckb_transaction
  belongs_to :script
  belongs_to :cell_output, foreign_key: "contract_cell_id", class_name: "CellOutput"
  enum :dep_type, [:code, :dep_group]

  def self.refresh_implicit
    connection.execute "SELECT update_cell_dependencies_implicit();"
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
