class CellDatum < ApplicationRecord
  self.primary_key = :cell_output_id
  belongs_to :cell_output, primary_key: :id, inverse_of: :cell_datum
  validates :data, presence: true, length: { minimum: 1 }

  after_save :update_data_hash, :update_data_size

  def update_data_hash
    cell_output.update(data_hash: CKB::Utils.bin_to_hex(CKB::Blake2b.digest(data)))
  end

  def update_data_size
    cell_output.update(data_size: data.bytesize)
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
