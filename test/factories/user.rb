FactoryBot.define do
  factory :user do
    uuid { SecureRandom.uuid }

    identifier do
      script = CKB::Types::Script.new(code_hash: Settings.secp_cell_type_hash, args: "0x#{SecureRandom.hex(20)}",
                                      hash_type: "type")
      CKB::Address.new(script).generate
    end
  end
end
