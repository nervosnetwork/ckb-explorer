namespace :migration do
	desc "Usage: RAILS_ENV=production bundle exec rake migration:fill_script_id_to_cell_outputs"
  task fill_script_id_to_cell_outputs: :environment do
    progress_bar = ProgressBar.create({ total: CellOutput.count, format: "%e %B %p%% %c/%C" })
	  CellOutput.select(:id, :lock_script_id, :type_script_id, :created_at).find_in_batches do |cell_outputs|
		  cell_outputs_attrs = []
		  cell_outputs.each do |output|
        progress_bar.increment
			  lock_script_id = output.lock_script.id
			  type_script_id = output.type_script&.id
			  cell_outputs_attrs << { id: output.id, lock_script_id: lock_script_id, type_script_id: type_script_id, created_at: output.created_at, updated_at: Time.current }
		  end

		  CellOutput.upsert_all(cell_outputs_attrs) if cell_outputs_attrs.present?
	  end
    puts "done"
  end
end
