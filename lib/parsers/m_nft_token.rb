class Parsers::MNftToken
  include Sidekiq::Worker

  def perform(cell_id)
    cell = CellOutput.find cell_id
    factory_data = CellOutput.where(
      type_script_id: nrc_721_factory_cell_type.id, 
      cell_type: "nrc_721_factory").last.data
    cell.update parsed_data: CkbUtils.parse_nrc_721_factory_data(factory_data)
  end
end
