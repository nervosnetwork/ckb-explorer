# TODO keep ReferringCell or CellDependency
# referring cells v2.
class ReferringCell < ApplicationRecord
  belongs_to :contract
  belongs_to :ckb_transaction
  belongs_to :cell_output

  # create initial data
  # please run this script
  def self.create_initial_data ckb_transaction_id = nil
    CkbTransaction.where("id <= ?", ckb_transaction_id).find_each do |ckb_transaction|
      self.create_initial_data_for_ckb_transaction ckb_transaction
    end
  end

  def self.create_initial_data_for_ckb_transaction ckb_transaction
    ckb_transaction.cell_outputs.each do |cell_output|
      contract_id = nil
      if cell_output.lock_script_id.present?
        contract_id = cell_output.lock_script.contract.id rescue nil
      elsif cell_output.type_script_id.present?
        contract_id = cell_output.type_script.contract.id rescue nil
      end
      ReferringCell.create_or_find_by(cell_output_id: cell_output.id, ckb_transaction_id: ckb_transaction.id, contract_id: contract_id) if contract_id.present?
    end
  end
end

# == Schema Information
#
# Table name: referring_cells
#
#  id                 :bigint           not null, primary key
#  cell_output_id     :bigint
#  contract_id        :bigint
#  ckb_transaction_id :bigint
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
