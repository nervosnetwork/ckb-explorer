class CellDatum < ApplicationRecord
  belongs_to :cell_output
  validates :data, presence: true, length: { minimum: 1 }
end

# == Schema Information
#
# Table name: cell_data
#
#  cell_output_id :bigint           not null, primary key
#  data           :binary           not null
#
