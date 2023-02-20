# this is the ReferringCell model
class CellDependency < ActiveRecord::Base

  belongs_to :contract, optional: true
  belongs_to :ckb_transaction
  belongs_to :script
  belongs_to :cell_output, foreign_key: "contract_cell_id", class_name: "CellOutput"

  # the_scripts:  type_scripts or lock_scripts
  # notice :
  # 1. stop the syncer process
  # 2. record the last TypeScript id(e.g. 666), and last LockScript id(e.g. 888)
  # 3. start the latest syncer process : bundle exec ruby lib/ckb_block_node_processor.rb
  # 3. run these methods:
  #    CellDependency.create_from_scripts TypeScript.where('id <= ?', 666)
  #    CellDependency.create_from_scripts LockScript.where('id <= ?', 888)
  def self.create_from_scripts the_scripts
    the_scripts.find_each do |the_script|
      Rails.logger.info "== processing the_script: #{the_script.id}"
      next if the_script.ckb_transactions.blank?

      the_script.ckb_transactions.each do |ckb_transaction|
        next if ckb_transaction.cell_outputs.blank?
        ckb_transaction.cell_outputs.each do |cell_output|
          the_hash = { ckb_transaction_id: ckb_transaction.id, contract_cell_id: cell_output.id, script_id: the_script.script_id }
          contract_id = the_script.script.contract_id
          if contract_id.present?
            the_hash.merge contract_id: contract_id
          end
          CellDependency.create! the_hash
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
#  script_id          :bigint
#
