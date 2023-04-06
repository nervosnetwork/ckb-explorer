class CellDatum < ApplicationRecord
  belongs_to :cell_output
  validates :data, presence: true
end
