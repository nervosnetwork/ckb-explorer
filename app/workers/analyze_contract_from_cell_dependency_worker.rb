class AnalyzeContractFromCellDependencyWorker
  include Sidekiq::Worker

  def perform
    cell_deps_out_points_attrs = Set.new
    contract_attrs = Set.new
    cell_deps_attrs = []

    CellDependency.where(contract_analyzed: false).limit(1000).each do |cell_dep|
      cell_deps_attrs << { contract_analyzed: true, ckb_transaction_id: cell_dep.ckb_transaction_id, contract_cell_id: cell_dep.contract_cell_id, dep_type: cell_dep.dep_type }

      next if CellDepsOutPoint.where(contract_cell_id: cell_dep.contract_cell_id).exists?

      ckb_transaction = CkbTransaction.find(cell_dep.ckb_transaction_id)

      type_script_hashes = Set.new
      lock_script_hashes = Set.new

      cell_outputs = ckb_transaction.cell_outputs.includes(:type_script).to_a
      cell_inputs = ckb_transaction.cell_inputs.includes(:previous_cell_output).map(&:previous_cell_output)
      cell_inputs.each do |input|
        lock_script_hashes << input.lock_script.code_hash
        type_script_hashes << input.type_script.code_hash if input.type_script
      end

      cell_outputs.each do |output|
        type_script_hashes << output.type_script.code_hash if output.type_script
      end

      case cell_dep.dep_type
      when "code"
        cell_output = cell_dep.cell_output
        cell_deps_out_points_attrs << {
          tx_hash: cell_output.tx_hash,
          cell_index: cell_output.cell_index,
          deployed_cell_output_id: cell_output.id,
          contract_cell_id: cell_output.id,
        }

        is_lock_script = cell_output.type_script&.script_hash.in?(lock_script_hashes) || cell_output.data_hash.in?(lock_script_hashes)
        is_type_script = cell_output.type_script&.script_hash.in?(type_script_hashes) || cell_output.data_hash.in?(type_script_hashes)

        if is_lock_script || is_type_script
          contract_attrs <<
            {
              type_hash: cell_output.type_script&.script_hash,
              data_hash: cell_output.data_hash,
              deployed_cell_output_id: cell_output.id,
              is_type_script:,
              is_lock_script:,
              deployed_args: cell_output.type_script&.args,
            }
        end

      when "dep_group"
        # when the type of cell_dep is "dep_group", it means the cell specified by the `out_point` is a list of out points to the actual referred contract cells
        mid_cell = cell_dep.cell_output

        binary_data = mid_cell.binary_data
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

          is_lock_script = cell_output.type_script&.script_hash.in?(lock_script_hashes) || cell_output.data_hash.in?(lock_script_hashes)
          is_type_script = cell_output.type_script&.script_hash.in?(type_script_hashes) || cell_output.data_hash.in?(type_script_hashes)

          if is_lock_script || is_type_script
            contract_attrs <<
              {
                type_hash: cell_output.type_script&.script_hash,
                data_hash: cell_output.data_hash,
                deployed_cell_output_id: cell_output.id,
                deployed_args: cell_output.type_script&.args,
                is_type_script:,
                is_lock_script:,
              }
          end
        end
      end
    end
    if cell_deps_out_points_attrs.any?
      CellDepsOutPoint.upsert_all(cell_deps_out_points_attrs,
                                  unique_by: %i[contract_cell_id deployed_cell_output_id])
    end
    Contract.upsert_all(contract_attrs, unique_by: %i[deployed_cell_output_id]) if contract_attrs.any?
    CellDependency.upsert_all(cell_deps_attrs, unique_by: %i[ckb_transaction_id contract_cell_id dep_type], update_only: :contract_analyzed)
  end
end
