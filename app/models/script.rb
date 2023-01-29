class Script < ActiveRecord::Base
  has_many :lock_scripts
  has_many :type_scripts

  def self.create_initial_data
    TypeScript.find_each do |type_script|
      script = Script.find_or_create_by(args: type_script.args, script_hash: type_script.script_hash)
      type_script.update script_id: script.id
    end

    LockScript.find_each do |lock_script|
      script = Script.find_or_create_by(args: lock_script.args, script_hash: lock_script.script_hash)
      lock_script.update script_id: script.id
    end
  end

  def to_node
    {
      args: args,
      code_hash: code_hash,
      hash_type: hash_type
    }
  end

  def as_json(options={})
    {
      args: args,
      code_hash: code_hash,
      hash_type: hash_type,
      script_hash: script_hash
    }
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
