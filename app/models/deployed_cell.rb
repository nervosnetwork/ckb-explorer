class DeployedCell < ApplicationRecord
  belongs_to :contract, optional: true
  belongs_to :cell_output, optional: true
  has_many :lock_scripts
  has_many :type_scripts

  def self.create_initial_data
    DeployedCell.transaction do
      CellOutput.find_each do | cell_output |
        if cell_output.type_script_id.present?
          contract_id = cell_output.type_script.script.contract_id
          if contract_id.present?
            DeployedCell.create cell_output_id: cell_output.id, contract_id: contract_id
          else
            Rails.logger.info "the contract id for this TypeScript is blank"
          end
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
#  is_initialized :boolean          default(FALSE)
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
