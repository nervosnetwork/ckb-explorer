class CopyCellData < ActiveRecord::Migration[7.0]
  def change
    CellOutput.where.not(data: nil).where.not(data: "0x").find_each do |c|
      d = c.cell_datum
      d.update data: CKB::Utils.hex_to_bin(c.data)
    end
  end
end
