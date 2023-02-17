# TODO
# referring cell
class CellDependency < ActiveRecord::Base

  belongs_to :contract
  belongs_to :ckb_transaction
  belongs_to :cell_output, foreign_key: "contract_cell_id", class_name: "CellOutput"

  # the_scripts:  type_scripts or lock_scripts
  # Usage:
  # bundle exec rails c
  # rails > CellDependency.create_from_scripts TypeScript.all
  # rails > CellDependency.create_from_scripts LockScript.all
  def self.create_from_scripts the_scripts
    the_scripts.find_each do |the_script|
      CkbTransaction.transaction do
        next if the_script.ckb_transactions.blank?
        the_script.ckb_transactions.each do |ckb_transaction|
          next if ckb_transaction.cell_outputs.blank?
          ckb_transaction.cell_outputs.each do |cell_output|
            CellDependency.create contract_id: the_script.script.contract_id, ckb_transaction_id: ckb_transaction.id, contract_cell_id: cell_output.id
          end
        end
      end
    end
  end

end

# == Schema Information
#
# Table name: cell_dependencies
#
#  id                 :bigint           not null, primary key
#  contract_id        :bigint
#  ckb_transaction_id :bigint
#  dep_type           :integer
#  contract_cell_id   :bigint
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
