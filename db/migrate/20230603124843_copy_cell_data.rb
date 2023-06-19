class CopyCellData < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!
  def change
    i = CellDatum.maximum(:cell_output_id)
    CellOutput.where("id>?", i || 0).where("data is not null and length(data) > 2").find_each do |c|
      d = c.cell_datum || c.build_cell_datum
      d.data = CKB::Utils.hex_to_bin(c[:data])
      d.save validate: false
    end
  end
end
