namespace :migration do
  desc "Usage: RAILS_ENV=production bundle exec rake migration:analyze_contract_from_start_block"
  task analyze_contract_from_start_block: :environment do
    loop do
      cell_deps_out_points_attrs = Set.new
      contract_attrs = Set.new
      cell_deps_attrs = Set.new
      contract_roles = Hash.new { |hash, key| hash[key] = {} }

      CellDependency.where(contract_analyzed: false).where.not(block_number: nil).limit(1000).group_by do |cell_dep|
        cell_dep.ckb_transaction_id
      end.each do |ckb_transaction_id, cell_deps|
        ckb_transaction = CkbTransaction.find(ckb_transaction_id)
        type_scripts = Hash.new
        lock_scripts = Hash.new

        cell_outputs = ckb_transaction.cell_outputs.includes(:type_script).to_a
        cell_inputs = ckb_transaction.cell_inputs.includes(:previous_cell_output).map(&:previous_cell_output)
        cell_inputs.each do |input|
          lock_scripts[input.lock_script.code_hash] = input.lock_script.hash_type
          type_scripts[input.type_script.code_hash] = input.type_script.hash_type if input.type_script
        end
        cell_outputs.each do |output|
          lock_scripts[output.lock_script.code_hash] = output.lock_script.hash_type
          type_scripts[output.type_script.code_hash] = output.type_script.hash_type if output.type_script
        end

        cell_deps.each do |cell_dep|
          cell_deps_attrs << { contract_analyzed: true, ckb_transaction_id: cell_dep.ckb_transaction_id, contract_cell_id: cell_dep.contract_cell_id, dep_type: cell_dep.dep_type }
          next if Contract.joins(:cell_deps_out_points).where(cell_deps_out_points: { contract_cell_id: cell_dep.contract_cell_id }).exists?

          case cell_dep.dep_type
          when "code"
            cell_output = cell_dep.cell_output
            cell_deps_out_points_attrs << {
              tx_hash: cell_output.tx_hash,
              cell_index: cell_output.cell_index,
              deployed_cell_output_id: cell_output.id,
              contract_cell_id: cell_output.id,
            }

            is_lock_script = (lock_scripts[cell_output.data_hash] || lock_scripts[cell_output.type_script&.script_hash]).present?
            is_type_script = (type_scripts[cell_output.data_hash] || type_scripts[cell_output.type_script&.script_hash]).present?
            data_type = lock_scripts[cell_output.data_hash] || type_scripts[cell_output.data_hash]
            contract_roles[cell_output.id][:is_lock_script] ||= is_lock_script
            contract_roles[cell_output.id][:is_type_script] ||= is_type_script
            contract_roles[cell_output.id][:hash_type] ||= data_type

            if is_lock_script || is_type_script
              contract_attrs <<
                {
                  type_hash: cell_output.type_script&.script_hash,
                  data_hash: cell_output.data_hash,
                  deployed_cell_output_id: cell_output.id,
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

              is_lock_script = (lock_scripts[cell_output.data_hash] || lock_scripts[cell_output.type_script&.script_hash]).present?
              is_type_script = (type_scripts[cell_output.data_hash] || type_scripts[cell_output.type_script&.script_hash]).present?
              hash_type = lock_scripts[cell_output.data_hash] || type_scripts[cell_output.data_hash]
              contract_roles[cell_output.id][:is_lock_script] ||= is_lock_script
              contract_roles[cell_output.id][:is_type_script] ||= is_type_script
              contract_roles[cell_output.id][:hash_type] ||= hash_type

              if is_lock_script || is_type_script
                contract_attrs <<
                  {
                    type_hash: cell_output.type_script&.script_hash,
                    data_hash: cell_output.data_hash,

                    deployed_cell_output_id: cell_output.id,
                    deployed_args: cell_output.type_script&.args,
                  }
              end
            end
          end
        end
      end
      if cell_deps_out_points_attrs.any?
        CellDepsOutPoint.upsert_all(cell_deps_out_points_attrs,
                                    unique_by: %i[contract_cell_id deployed_cell_output_id])
      end
      # some contract in a cell may be lock script but in another cell may be type script
      if contract_attrs.any?
        new_contract_attrs =
          contract_attrs.map do |attr|
            attr.merge(contract_roles[attr[:deployed_cell_output_id]])
          end
        puts new_contract_attrs
        Contract.upsert_all(new_contract_attrs, unique_by: %i[deployed_cell_output_id])
      end
      CellDependency.upsert_all(cell_deps_attrs, unique_by: %i[ckb_transaction_id contract_cell_id dep_type], update_only: :contract_analyzed)

      break unless CellDependency.where(contract_analyzed: false).where.not(block_number: nil).exists?
    end
    puts "DONE"
  end
end
