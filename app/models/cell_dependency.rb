# this is the ReferringCell model, parse from `cell_deps` of transaction raw hash
class CellDependency < ApplicationRecord
  belongs_to :ckb_transaction
  belongs_to :cell_output, foreign_key: "contract_cell_id", class_name: "CellOutput"
  has_many :cell_deps_point_outputs, foreign_key: :contract_cell_id, primary_key: :contract_cell_id

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

  def self.parse_cell_dpes_from_ckb_transaction(ckb_transaction, cell_deps)
    return if cell_deps.blank?

    cell_dependencies_attrs = []
    cell_deps_out_points_attrs = Set.new
    contract_attrs = Set.new

    cell_deps.each do |cell_dep|
      if cell_dep.is_a?(CKB::Types::CellDep)
        cell_dep = cell_dep.to_h.with_indifferent_access
      end
      case cell_dep["dep_type"]
      when "code"
        cell_output = CellOutput.find_by_pointer cell_dep["out_point"]["tx_hash"], cell_dep["out_point"]["index"]
        cell_dependencies_attrs << {
          contract_cell_id: cell_output.id,
          dep_type: cell_dep["dep_type"],
          ckb_transaction_id: ckb_transaction.id,
          block_number: ckb_transaction.block_number,
          tx_index: ckb_transaction.tx_index,
        }

        cell_deps_out_points_attrs << {
          tx_hash: cell_dep["out_point"]["tx_hash"],
          cell_index: cell_dep["out_point"]["index"],
          deployed_cell_output_id: cell_output.id,
          contract_cell_id: cell_output.id,
        }

        contract_attrs <<
          {
            type_hash: cell_output.type_script&.script_hash,
            data_hash: cell_output.data_hash,
            deployed_cell_output_id: cell_output.id,
            is_type_script: TypeScript.type_script(cell_output.type_script&.script_hash, cell_output.data_hash).exists?,
            is_lock_script: LockScript.lock_script(cell_output.type_script&.script_hash, cell_output.data_hash).exists?,
            deployed_args: cell_output.type_script&.args,
          }

      when "dep_group"
        # when the type of cell_dep is "dep_group", it means the cell specified by the `out_point` is a list of out points to the actual referred contract cells
        mid_cell = CellOutput.find_by_pointer cell_dep["out_point"]["tx_hash"], cell_dep["out_point"]["index"]

        cell_dependencies_attrs << {
          contract_cell_id: mid_cell.id,
          dep_type: cell_dep["dep_type"],
          ckb_transaction_id: ckb_transaction.id,
          block_number: ckb_transaction.block_number,
          tx_index: ckb_transaction.tx_index,
        }

        binary_data = mid_cell.binary_data
        # binary_data = [hex_data[2..-1]].pack("H*")
        # parse the actual list of out points from the data field of the cell
        out_points_count = binary_data[0, 4].unpack("L<")
        # iterate over the out point list and append actual referred contract cells to cell dependencies_attrs
        0.upto(out_points_count[0] - 1) do |i|
          part_tx_hash, cell_index = binary_data[4 + i * 36, 36].unpack("H64L<")
          tx_hash = "0x#{part_tx_hash}"
          cell_output = CellOutput.find_by_pointer tx_hash, cell_index
          cell_deps_out_points_attrs << {
            tx_hash:,
            cell_index:,
            deployed_cell_output_id: cell_output.id,
            contract_cell_id: mid_cell.id,
          }

          contract_attrs <<
            {
              type_hash: cell_output.type_script&.script_hash,
              data_hash: cell_output.data_hash,
              is_type_script: TypeScript.type_script(cell_output.type_script&.script_hash, cell_output.data_hash).exists?,
              is_lock_script: LockScript.lock_script(cell_output.type_script&.script_hash, cell_output.data_hash).exists?,
              deployed_cell_output_id: cell_output.id,
              deployed_args: cell_output.type_script&.args,
            }
        end
      end
    end
    CellDependency.upsert_all(cell_dependencies_attrs,
                              unique_by: %i[ckb_transaction_id contract_cell_id], update_only: %i[block_number tx_index])
    CellDepsOutPoint.upsert_all(cell_deps_out_points_attrs,
                                unique_by: %i[contract_cell_id deployed_cell_output_id])
    Contract.upsert_all(contract_attrs, unique_by: %i[deployed_cell_output_id], update_only: %i[is_lock_script is_type_script])
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
#  script_id          :bigint
#  contract_id        :bigint
#  implicit           :boolean
#  block_number       :bigint
#  tx_index           :integer
#
# Indexes
#
#  cell_deps_tx_cell_idx                                 (ckb_transaction_id,contract_cell_id) UNIQUE
#  index_cell_dependencies_on_block_number_and_tx_index  (block_number,tx_index)
#  index_cell_dependencies_on_contract_cell_id           (contract_cell_id)
#
