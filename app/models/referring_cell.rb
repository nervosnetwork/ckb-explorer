class ReferringCell < ApplicationRecord
  belongs_to :contract
  belongs_to :ckb_transaction
  belongs_to :cell_output
end

# == Schema Information
#
# Table name: referring_cells
#
#  id                   :bigint           not null, primary key
#  cell_output_id       :bigint
#  contract_id          :bigint
#  ckb_transaction_id   :bigint
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
