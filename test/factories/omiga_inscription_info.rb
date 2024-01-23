FactoryBot.define do
  factory :omiga_inscription_info do
    udt_hash do
      "0x5fa66c8d5f43914f85d3083e0529931883a5b0a14282f891201069f1b5067908"
    end
    code_hash do
      "0x50fdea2d0030a8d0b3d69f883b471cab2a29cae6f01923f19cecac0f27fdaaa6"
    end
    hash_type { "type" }
    args do
      "0xcd89d8f36593a9a82501c024c5cdc4877ca11c5b3d5831b3e78334aecb978f0d"
    end
    type_hash do
      "0x5cfcab1fc499de7d33265b04d2de9cf2f91cc7c7a578642993b0912b31b6cf39"
    end
  end
end
