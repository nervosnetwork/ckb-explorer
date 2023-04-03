class Script < ActiveRecord::Base
  has_many :lock_scripts
  has_many :type_scripts
  has_many :cell_dependencies

  has_many :script_transactions
  has_many :ckb_transactions, through: :script_transactions

  belongs_to :contract, optional: true

  def self.create_initial_data
    contracts = {}
    Contract.all.each do |contract|
      contracts[contract.code_hash] = contract
    end
    TypeScript.find_each do |type_script|
      contract_id = contracts[type_script.code_hash]&.id

      temp_hash = { args: type_script.args, script_hash: type_script.script_hash, is_contract: false }
      if contract_id
        temp_hash = temp_hash.merge is_contract: true, contract_id: contract_id
      end

      script = Script.create_or_find_by temp_hash
      type_script.update script_id: script.id
    end

    LockScript.find_each do |lock_script|
      contract_id = contracts[lock_script.code_hash]&.id

      temp_hash = { args: lock_script.args, script_hash: lock_script.script_hash, is_contract: false }
      if contract_id
        temp_hash = temp_hash.merge is_contract: true, contract_id: contract_id
      end
      script = Script.create_or_find_by temp_hash
      lock_script.update script_id: script.id
    end

    Rails.logger.info "== Script.create_initial_data done"
  end
end

# == Schema Information
#
# Table name: scripts
#
#  id          :bigint           not null, primary key
#  args        :string
#  script_hash :string
#  is_contract :boolean          default(FALSE)
#  contract_id :bigint
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_scripts_on_contract_id  (contract_id)
#
