class CellDepsOutPoint < ApplicationRecord
  belongs_to :cell_dependency, foreign_key: :contract_cell_id, primary_key: :contract_cell_id
  belongs_to :contract, foreign_key: :deployed_cell_id, primary_key: :deployed_cell_id
end

# == Schema Information
#
# Table name: cell_deps_out_points
#
#  id                      :bigint           not null, primary key
#  tx_hash                 :binary
#  cell_index              :integer
#  deployed_cell_output_id :bigint
#  contract_cell_id        :bigint
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#
# Indexes
#
#  index_cell_deps_out_points_on_contract_cell_id_deployed_cell_id  (contract_cell_id,deployed_cell_output_id) UNIQUE
#
