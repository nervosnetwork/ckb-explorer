# this is the ReferringCell model
class CellDependency < ActiveRecord::Base
  belongs_to :contract, optional: true
  belongs_to :ckb_transaction
  belongs_to :script
  belongs_to :cell_output, foreign_key: "contract_cell_id", class_name: "CellOutput"
  enum :dep_type, [:code, :dep_group]

  def self.create_initial_data
    CkbTransaction.find_in_batches do |txs|
      recs = []
      txs.each do |t|
        recs +=
          t.cell_deps.map do |d|
            cell = CellOutput.find_by_pointer d["out_point"]["tx_hash"], d["out_point"]["index"].hex
            {
              contract_id: cell,
              contract_cell_id: cell.id,
              dep_type: d["dep_type"]
            }
          end
      end
    end
  end

  # please run these methods:
  #    CellDependency.create_from_scripts TypeScript.all
  #    CellDependency.create_from_scripts LockScript.all
  def self.create_from_scripts(the_scripts)
    the_scripts.find_each do |the_script|
      Rails.logger.info "== processing the_script: #{the_script.id}"
      next if the_script.ckb_transactions.blank?

      hashes = []
      the_script.ckb_transactions.each do |ckb_transaction|
        next if ckb_transaction.cell_outputs.blank?

        ckb_transaction.cell_outputs.each do |cell_output|
          the_hash = {
            ckb_transaction_id: ckb_transaction.id,
            contract_cell_id: cell_output.id,
            script_id: the_script.script_id,
            contract_id: the_script.script.contract_id
          }
          hashes << the_hash
        end
      end
      CellDependency.upsert_all hashes, unique_by: [:ckb_transaction_id, :contract_cell_id]
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
# Indexes
#
#  index_cell_dependencies_on_contract_cell_id  (contract_cell_id)
#  index_cell_dependencies_on_contract_id       (contract_id)
#  index_cell_dependencies_on_script_id         (script_id)
#
