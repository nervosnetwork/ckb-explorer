namespace :migration do
  desc "Usage: RAILS_ENV=production bundle exec rake migration:fill_cell_deps_out_point"
  task fill_cell_deps_out_point: :environment do
    ActiveRecord::Base.connection.execute("SET statement_timeout = 0")
    error_ids = []
    CellDependency.left_joins(:cell_deps_out_point).where(cell_deps_out_point: { id: nil }).select(:contract_cell_id).distinct.in_batches do |batch|
      batch.each do |missed_cell_dep|
        CellDependency.where(contract_cell_id: missed_cell_dep.contract_cell_id).select(:dep_type).distinct.each do |cell_dep|
          if cell_dep.dep_type == "code"
            output = CellOutput.find(missed_cell_dep.contract_cell_id)
            CellDepsOutPoint.upsert_all([tx_hash: output.tx_hash, cell_index: output.cell_index, deployed_cell_output_id: output.id, contract_cell_id: output.id])
          else
            cell_deps_out_points_attrs = []
            mid_cell = CellOutput.find(missed_cell_dep.contract_cell_id)
            binary_data = mid_cell.binary_data
            out_points_count = binary_data[0, 4].unpack("L<")
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
            end
            CellDepsOutPoint.upsert_all(cell_deps_out_points_attrs)
          end
        rescue StandardError => _e
          error_ids << missed_cell_dep.contract_cell_id
        end
      end
    end
    puts "done"
  end
end
