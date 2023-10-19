# TODO keep ReferringCell or CellDependency
# referring cells v2.
class ReferringCell < ApplicationRecord
  belongs_to :contract
  belongs_to :ckb_transaction
  belongs_to :cell_output

  # create initial data
  # please run this script
  def self.create_initial_data(ckb_transaction_id = nil)
    CkbTransaction.where("id <= ?", ckb_transaction_id).find_each do |ckb_transaction|
      self.create_initial_data_for_ckb_transaction ckb_transaction
    end
  end

  def self.create_initial_data_for_ckb_transaction(ckb_transaction)
    inputs = ckb_transaction.inputs
    outputs = ckb_transaction.outputs

    (inputs + outputs).each do |cell|
      contracts = [cell.lock_script.contract, cell.type_script&.contract].compact

      next if contracts.empty?

      contracts.each do |contract|
        if cell.live?
          ReferringCell.create_or_find_by(
            cell_output_id: cell.id,
            ckb_transaction_id: ckb_transaction.id,
            contract_id: contract.id
          )
        elsif cell.dead?
          referring_cell = ReferringCell.find_by(
            cell_output_id: cell.id,
            ckb_transaction_id: ckb_transaction.id,
            contract_id: contract.id
          )

          referring_cell.destroy if referring_cell
        end
      end
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
# Indexes
#
#  index_referring_cells_on_contract_id_and_cell_output_id  (contract_id,cell_output_id) UNIQUE
#
