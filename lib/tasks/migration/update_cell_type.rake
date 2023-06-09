namespace :migration do
  desc "Usage: RAILS_ENV=production bundle exec rake migration:update_cell_type"
  task update_cell_type: :environment do
    cota_registry_scripts = TypeScript.where(code_hash: CkbSync::Api.instance.cota_registry_code_hash)
    cota_regular_scripts = TypeScript.where(code_hash: CkbSync::Api.instance.cota_regular_code_hash)
    total_count = cota_registry_scripts.count + cota_regular_scripts.count

    progress_bar = ProgressBar.create({ total: total_count, format: "%e %B %p%% %c/%C" })

    cota_registry_scripts.each do |ts|
      cell_type = CkbUtils.cell_type(ts, "0x")
      CellOutput.where(type_script_id: ts.id).in_batches do |cell_outputs|
        cell_outputs.update_all(cell_type: cell_type)
        cell_output_ids = cell_outputs.pluck(:id)
        CellInput.where(previous_cell_output_id: cell_output_ids).update_all(cell_type: cell_type)
      end

      progress_bar.increment
    end

    cota_regular_scripts.each do |ts|
      cell_type = CkbUtils.cell_type(ts, "0x")
      CellOutput.where(type_script_id: ts.id).in_batches do |cell_outputs|
        cell_outputs.update_all(cell_type: cell_type)
        cell_output_ids = cell_outputs.pluck(:id)
        CellInput.where(previous_cell_output_id: cell_output_ids).update_all(cell_type: cell_type)
      end

      progress_bar.increment
    end

    puts "done"
  end
end
