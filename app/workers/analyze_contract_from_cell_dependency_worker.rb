class AnalyzeContractFromCellDependencyWorker
  include Sidekiq::Worker

  sidekiq_options queue: "critical", retry: 0
  sidekiq_options lock: :until_executed

  def perform
    cell_deps_out_points_attrs = Set.new
    contract_attrs = Set.new
    cell_deps_attrs = Set.new
    contract_roles = Hash.new { |hash, key| hash[key] = {} }

    dependencies = load_unanalyzed_dependencies

    dependencies.each do |ckb_transaction_id, cell_deps|
      ckb_transaction = CkbTransaction.find(ckb_transaction_id)
      lock_scripts, type_scripts = analyze_scripts(ckb_transaction)

      process_cell_dependencies(
        cell_deps,
        lock_scripts,
        type_scripts,
        cell_deps_out_points_attrs,
        contract_attrs,
        cell_deps_attrs,
        contract_roles,
      )
    end

    save_cell_deps_out_points(cell_deps_out_points_attrs)
    save_contracts(contract_attrs, contract_roles)
    save_cell_dependencies(cell_deps_attrs)
  end

  private

  def load_unanalyzed_dependencies
    CellDependency.where(contract_analyzed: false).
      where.not(block_number: nil).
      limit(200).
      group_by(&:ckb_transaction_id)
  end

  def analyze_scripts(ckb_transaction)
    lock_scripts = {}
    type_scripts = {}

    cell_outputs = ckb_transaction.cell_outputs.includes(:type_script).to_a
    cell_inputs = ckb_transaction.cell_inputs.includes(:previous_cell_output).map(&:previous_cell_output)

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

    [lock_scripts, type_scripts]
  end

  def process_cell_dependencies(cell_deps, lock_scripts, type_scripts, out_points_attrs, contract_attrs, cell_deps_attrs, contract_roles)
    cell_deps.each do |cell_dep|
      is_used =
        case cell_dep.dep_type
        when "code"
          process_code_dep(cell_dep, lock_scripts, type_scripts, out_points_attrs, contract_attrs, contract_roles)
        when "dep_group"
          process_dep_group(cell_dep, lock_scripts, type_scripts, out_points_attrs, contract_attrs, contract_roles)
        end

      cell_deps_attrs << {
        contract_analyzed: true,
        is_used:,
        ckb_transaction_id: cell_dep.ckb_transaction_id,
        contract_cell_id: cell_dep.contract_cell_id,
        dep_type: cell_dep.dep_type,
      }
    end
  end

  def process_code_dep(cell_dep, lock_scripts, type_scripts, out_points_attrs, contract_attrs, contract_roles)
    cell_output = cell_dep.cell_output
    out_points_attrs << {
      tx_hash: cell_output.tx_hash,
      cell_index: cell_output.cell_index,
      deployed_cell_output_id: cell_output.id,
      contract_cell_id: cell_output.id,
    }

    update_contract_roles(cell_output, lock_scripts, type_scripts, contract_roles)

    if contract_roles[cell_output.id][:is_lock_script] || contract_roles[cell_output.id][:is_type_script]
      contract_attrs << build_contract_attr(cell_output)
      true
    else
      false
    end
  end

  def process_dep_group(cell_dep, lock_scripts, type_scripts, out_points_attrs, contract_attrs, contract_roles)
    mid_cell = cell_dep.cell_output
    binary_data = mid_cell.binary_data
    out_points_count = binary_data[0, 4].unpack1("L<")
    is_used = false

    0.upto(out_points_count - 1) do |i|
      part_tx_hash, cell_index = binary_data[4 + i * 36, 36].unpack("H64L<")
      tx_hash = "0x#{part_tx_hash}"
      cell_output = CellOutput.find_by_pointer(tx_hash, cell_index)

      out_points_attrs << {
        tx_hash:,
        cell_index:,
        deployed_cell_output_id: cell_output.id,
        contract_cell_id: mid_cell.id,
      }

      update_contract_roles(cell_output, lock_scripts, type_scripts, contract_roles)

      if contract_roles[cell_output.id][:is_lock_script] || contract_roles[cell_output.id][:is_type_script]
        contract_attrs << build_contract_attr(cell_output)
        is_used = is_used || true
      end
    end
    is_used
  end

  def update_contract_roles(cell_output, lock_scripts, type_scripts, contract_roles)
    is_lock_script = (lock_scripts[cell_output.data_hash] || lock_scripts[cell_output.type_script&.script_hash]).present?
    is_type_script = (type_scripts[cell_output.data_hash] || type_scripts[cell_output.type_script&.script_hash]).present?
    data_type = lock_scripts[cell_output.data_hash] || type_scripts[cell_output.data_hash]

    contract_roles[cell_output.id][:is_lock_script] ||= is_lock_script
    contract_roles[cell_output.id][:is_type_script] ||= is_type_script
    contract_roles[cell_output.id][:hash_type] ||= data_type
  end

  def build_contract_attr(cell_output)
    {
      type_hash: cell_output.type_script&.script_hash,
      data_hash: cell_output.data_hash,
      deployed_cell_output_id: cell_output.id,
      deployed_args: cell_output.type_script&.args,
    }
  end

  def save_cell_deps_out_points(attrs)
    CellDepsOutPoint.upsert_all(attrs.to_a, unique_by: %i[contract_cell_id deployed_cell_output_id]) if attrs.any?
  end

  def save_contracts(attrs, roles)
    return if attrs.empty?

    new_attrs = attrs.map { |attr| attr.merge(roles[attr[:deployed_cell_output_id]]) }
    Contract.upsert_all(new_attrs, unique_by: %i[deployed_cell_output_id])
  end

  def save_cell_dependencies(attrs)
    CellDependency.upsert_all(attrs.to_a, unique_by: %i[ckb_transaction_id contract_cell_id dep_type], update_only: %i[contract_analyzed is_used]) if attrs.any?
  end
end
