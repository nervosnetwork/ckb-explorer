class GenerateStatisticsDataWorker
  include Sidekiq::Worker

  def perform(block_id)
    block = Block.find_by(id: block_id)
    if block.blank?
      # maybe the block record has not been persisted, so retry later
      return GenerateStatisticsDataWorker.perform_in(30.seconds, block_id)
    end

    node_block = CkbSync::Api.instance.get_block_by_number(block.number)
    block_size = node_block.serialized_size_without_uncle_proposals
    block.update(block_size: block_size)

    # update largest block information in epoch stats
    epoch_stats = EpochStatistic.find_by epoch_number: block.epoch

    if epoch_stats && epoch_stats.largest_block_size.to_i < block_size
      epoch_stats.update(largest_block_size: block_size, largest_block_number: block.number)
    end

    cell_outputs = block.cell_outputs.select(:id, :created_at, :data, :capacity, :lock_script_id, :type_script_id).to_a
    cell_outputs_attributes = []
    cell_outputs.each do |cell_output|
      cell_outputs_attributes << {
        id: cell_output.id,
        data_size: CKB::Utils.hex_to_bin(cell_output.data).bytesize,
        occupied_capacity: CkbUtils.calculate_cell_min_capacity(cell_output.node_output, cell_output.data),
        created_at: cell_output.created_at,
        updated_at: Time.current
      }
    end

    CellOutput.upsert_all(cell_outputs_attributes) if cell_outputs_attributes.present?
  end
end
