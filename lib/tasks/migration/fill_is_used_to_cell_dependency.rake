namespace :migration do
  desc "Usage: RAILS_ENV=production bundle exec rake migration:fill_is_used_to_cell_dependency[0,10000]"
  task :fill_is_used_to_cell_dependency, %i[start_block end_block] => :environment do |_, args|
    $error_ids = Set.new
    ActiveRecord::Base.connection.execute("SET statement_timeout = 0")
    (args[:start_block].to_i..args[:end_block].to_i).to_a.each_slice(100).to_a.each do |range|
      fill_is_used(range)
    end; nil
    puts "error IDS:"
    puts $error_ids.join(",")
    puts "done"
  end

  private

  def fill_is_used(range)
    puts range.first
    cell_deps_attrs = Set.new
    CellDependency.where(block_number: range).group_by { |cell_dep| cell_dep.ckb_transaction_id }.each do |tx_id, cell_deps|
      ckb_transaction = CkbTransaction.find_by(id: tx_id)
      if ckb_transaction
        type_scripts = Hash.new
        lock_scripts = Hash.new

        cell_outputs = ckb_transaction.cell_outputs.includes(:type_script).to_a
        cell_inputs = ckb_transaction.input_cells.includes(:lock_script, :type_script).to_a
        cell_inputs.each do |cell|
          lock_scripts[cell.lock_script.code_hash] = cell.lock_script.hash_type
          if cell.type_script
            type_scripts[cell.type_script.code_hash] = cell.type_script.hash_type
          end
        end
        cell_outputs.each do |cell|
          if cell.type_script
            type_scripts[cell.type_script.code_hash] = cell.type_script.hash_type
          end
        end

        cell_deps.each do |cell_dep|
          case cell_dep.dep_type
          when "code"
            process_code_dep(cell_dep, lock_scripts, type_scripts, cell_deps_attrs)
          when "dep_group"
            process_dep_group(cell_dep, lock_scripts, type_scripts, cell_deps_attrs)
          end
        end
      end
    end
    CellDependency.upsert_all(cell_deps_attrs.to_a, unique_by: %i[ckb_transaction_id contract_cell_id dep_type], update_only: :is_used) if cell_deps_attrs.any?
  end

  def process_code_dep(cell_dep, lock_scripts, type_scripts, cell_deps_attrs)
    cell_output = cell_dep.cell_output
    script_hash = cell_output.type_script&.script_hash
    is_lock_script = (lock_scripts[cell_output.data_hash] || lock_scripts[script_hash]).present?
    is_type_script = (type_scripts[cell_output.data_hash] || type_scripts[script_hash]).present?
    unless is_lock_script || is_type_script
      cell_deps_attrs << { ckb_transaction_id: cell_dep.ckb_transaction_id,
                           contract_cell_id: cell_dep.contract_cell_id,
                           dep_type: cell_dep.dep_type, is_used: false }
    end
  end

  def process_dep_group(cell_dep, lock_scripts, type_scripts, cell_deps_attrs)
    mid_cell = cell_dep.cell_output
    binary_data = mid_cell.binary_data
    out_points_count = binary_data[0, 4].unpack1("L<")
    is_used = false

    0.upto(out_points_count - 1) do |i|
      part_tx_hash, cell_index = binary_data[4 + i * 36, 36].unpack("H64L<")
      tx_hash = "0x#{part_tx_hash}"
      cell_output = CellOutput.find_by_pointer(tx_hash, cell_index)
      script_hash = cell_output.type_script&.script_hash

      is_lock_script = (lock_scripts[cell_output.data_hash] || lock_scripts[script_hash]).present?
      is_type_script = (type_scripts[cell_output.data_hash] || type_scripts[script_hash]).present?
      if is_lock_script || is_type_script
        is_used = is_used || true
      end
    end
    unless is_used
      cell_deps_attrs << { ckb_transaction_id: cell_dep.ckb_transaction_id,
                           contract_cell_id: cell_dep.contract_cell_id,
                           dep_type: cell_dep.dep_type, is_used: false }

    end
  end
end
