FactoryBot.define do
  factory :contract do
    code_hash { "0x9bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce8" }
    hash_type { 'type' }
    deployed_args { '0x284c65a608e8e280aaa9c119a1a8fe0463a17151' }
    role { 'owner' }
    name { 'CKB COIN TEST' }
    symbol { 'TTF' }
    verified { false }
  end
end
