require "ruby-progressbar"

namespace :migration do
  task calculate_output_occupied_capacity: :environment do
    cell_outputs_count = CellOutput.count
    progress_bar = ProgressBar.create({
      total: cell_outputs_count,
      format: "%e %B %p%% %c/%C"
    })
    CellOutput.find_each do |cell_output|
      node_output = cell_output.node_output
      output_data = cell_output.data
      progress_bar.increment if cell_output.update(occupied_capacity: CkbUtils.occupied_capacity(node_output, output_data))
    end

    puts "done"
  end
end
