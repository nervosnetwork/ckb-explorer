require "ruby-progressbar"

namespace :migration do
  task calculate_outputs_data_size: :environment do
    cell_outputs_count = CellOutput.count
    progress_bar = ProgressBar.create({
      total: cell_outputs_count,
      format: "%e %B %p%% %c/%C"
    })
    CellOutput.find_each do |cell_output|
      output_data = cell_output.data
      progress_bar.increment if cell_output.update(data_size: CKB::Utils.hex_to_bin(output_data).bytesize)
    end

    puts "done"
  end
end
