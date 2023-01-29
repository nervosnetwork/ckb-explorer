FactoryBot.define do
  factory :script do
    args { "0x441714e000fedf3247292c7f34fb16db14f49d9f" }
    script_hash { '0x34551bdd3db215970d4dd031146c4bb5adc74a1faea5c717773c1a72c8f01855' }
    is_contract { false }
  end
end
