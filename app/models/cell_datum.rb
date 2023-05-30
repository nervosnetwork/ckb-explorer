class CellDatum < ApplicationRecord
  belongs_to :cell_output
  validates :data, presence: true, length: { minimum: 1 }

  after_create :update_data_hash

  def update_data_hash
    cell_output.update(data_hash: CKB::Utils.bin_to_hex(CKB::Blake2b.digest(data)))
  end
end

# == Schema Information
#
# Table name: cell_data
#
#  cell_output_id :bigint           not null, primary key
#  data           :binary           not null
#
