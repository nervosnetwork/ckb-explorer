FactoryBot.define do
  factory :lock_script do
    hash_type { "type" }
    args { "0x#{SecureRandom.hex(20)}" }
    code_hash { Settings.secp_cell_type_hash }
    before(:create) do |lock_script|
      lock_script.script_hash = CKB::Types::Script.new(code_hash: lock_script.code_hash, hash_type: lock_script.hash_type, args: lock_script.args).compute_hash
    end

    after(:create) do |lock_script|
      Address.find_or_create_by!(
        address_hash: CkbUtils.generate_address(lock_script.to_ckb_type),
        lock_hash: lock_script.script_hash,
        lock_script_id: lock_script.id,
      )
    end
  end
end
