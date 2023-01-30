class Script < ActiveRecord::Base
  has_many :lock_scripts
  has_many :type_scripts

  belongs_to :contract, optional: true

  def self.create_initial_data
    Script.transaction do
      TypeScript.find_each do |type_script|
        contract_id = 0
        Contract.all.each {|contract|
          if contract.code_hash == type_script.code_hash
            contract_id = contract.id
            break
          end
        }

        temp_hash = {args: type_script.args, script_hash: type_script.script_hash, is_contract: false}
        if contract_id != 0
          temp_hash = temp_hash.merge is_contract: true, contract_id: contract_id
        end

        script = Script.find_or_create_by temp_hash
        type_script.update script_id: script.id
      end
    end

    Script.transaction do
      LockScript.find_each do |lock_script|
        script = Script.find_or_create_by(args: lock_script.args, script_hash: lock_script.script_hash)
        lock_script.update script_id: script.id
      end
    end
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
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  contract_id :bigint
#
