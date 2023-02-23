class ScriptTransaction < ApplicationRecord
  belongs_to :script
  belongs_to :ckb_transaction

  # the_scripts:  type_scripts or lock_scripts
  # notice :
  # 1. stop the syncer process
  # 2. record the last Script id ( e.g. 888)
  # 3. start the latest syncer process : bundle exec ruby lib/ckb_block_node_processor.rb
  # 3. run these methods:
  #    ScriptTransaction.create_initial_data Script.last.id
  def self.create_initial_data to_script_id
    Script.where('id <= ?', to_script_id).find_each do |script|
      self.create_from_scripts script.type_scripts
      self.create_from_scripts script.lock_scripts
    end
  end

  def self.create_from_scripts type_scripts_or_lock_scripts

    type_scripts_or_lock_scripts.each do |temp_script|
      temp_script.cell_outputs.each do |cell_output|
        ScriptTransaction.find_or_create_by ckb_transaction_id: cell_output.ckb_transaction_id, script_id: temp_script.script_id
      end
    end
  end
end


# == Schema Information
#
# Table name: script_transactions
#
#  id                 :bigint           not null, primary key
#  script_id          :bigint
#  ckb_transaction_id :bigint
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
# Indexes
#
#  index_script_transactions_on_ckb_transaction_id  (ckb_transaction_id)
#  index_script_transactions_on_script_id           (script_id)
#
