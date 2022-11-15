class GenerateStatisticsDataWorker
  include Sidekiq::Worker

  def perform(block_id)
    block = Block.find_by(id: block_id)
    return if block.blank?

    node_block = CkbSync::Api.instance.get_block_by_number(block.number)
    block.update(block_size: node_block.serialized_size_without_uncle_proposals)
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
