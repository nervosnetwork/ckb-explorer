class DeployedCell < ApplicationRecord
  belongs_to :contract, optional: true
  belongs_to :cell_output, optional: true
  has_many :lock_scripts
  has_many :type_scripts

  def self.create_initial_data
    TypeScript.transaction do
      TypeScript.find_each do |type_script|
        contract = type_script.contract
        if contract.present?
          type_script.cell_outputs.each do | cell_output |
            DeployedCell.create cell_output_id: cell_output.id, contract_id: contract.id
          end
        else
          Rails.logger.info "the contract id for this TypeScript is blank"
        end
      end
    end

    LockScript.transaction do
      LockScript.find_each do |type_script|
        contract = type_script.contract
        if contract.present?
          type_script.cell_outputs.each do | cell_output |
            DeployedCell.create cell_output_id: cell_output.id, contract_id: contract.id
          end
        else
          Rails.logger.info "the contract id for this LockScript is blank"
        end
      end
    end
  end

end


# == Schema Information
#
# Table name: deployed_cells
#
#  id             :bigint           not null, primary key
#  cell_output_id :bigint
#  contract_id    :bigint
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
