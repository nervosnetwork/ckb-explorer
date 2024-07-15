class GenerateStatisticsDataWorker
  include Sidekiq::Worker
  sidekiq_options retry: 3

  def perform(block_id)
    block = Block.find(block_id)
    node_block = CkbSync::Api.instance.get_block_by_number(block.number)
    block_size = node_block.serialized_size_without_uncle_proposals
    block.update(block_size:)

    # update largest block information in epoch stats
    epoch_stats = EpochStatistic.find_by epoch_number: block.epoch

    if epoch_stats && epoch_stats.largest_block_size.to_i < block_size
      epoch_stats.update(largest_block_size: block_size, largest_block_number: block.number)
    end

    cell_outputs = block.cell_outputs.includes(:cell_datum)
    cell_outputs_attributes = []
    cell_outputs.each do |cell_output|
      data_size =
        if cell_output.data != "0x"
          CKB::Utils.hex_to_bin(cell_output.data).bytesize
        else
          0
        end

      cell_outputs_attributes << {
        tx_hash: cell_output.tx_hash,
        cell_index: cell_output.cell_index,
        status: cell_output.status,
        data_size:,
        occupied_capacity: CkbUtils.calculate_cell_min_capacity(cell_output.node_output, cell_output.data),
      }
    end

    CellOutput.upsert_all(cell_outputs_attributes, unique_by: %i[tx_hash cell_index status], record_timestamps: true) if cell_outputs_attributes.present?
  end
end
