class CopyCellData < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!
  def change
    CellOutput.where("data is not null and length(data) > 2").find_each do |c|
      d = c.cell_datum || c.build_cell_datum
      d.update! data: CKB::Utils.hex_to_bin(c[:data])
    end
  end
end
