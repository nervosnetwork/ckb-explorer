class CellDatum < ApplicationRecord
  self.primary_key = :cell_output_id
  belongs_to :cell_output, primary_key: :id, inverse_of: :cell_datum
  validates :data, length: { minimum: 1 }

  after_save :update_cell_data_hash_and_size

  def update_cell_data_hash_and_size
    cell_output.update_columns(
      data_hash: CKB::Utils.bin_to_hex(CKB::Blake2b.digest(data)),
      data_size: data.bytesize
    )
  end

  def hex_data
    @hex_data ||= CKB::Utils.bin_to_hex(data)
  end
end

# == Schema Information
#
# Table name: cell_data
#
#  cell_output_id :bigint           not null, primary key
#  data           :binary           not null
#
