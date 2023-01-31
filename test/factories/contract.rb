FactoryBot.define do
  factory :contract do
    code_hash { "0x5c5069eb0857efc65e1bca0c07df34c31663b3622fd3876c876320fc9634e2a8" }
    hash_type { 'type' }
    deployed_args { '0x284c65a608e8e280aaa9c119a1a8fe0463a17151' }
    role { 'type_script' }
    name { 'CKB COIN TEST' }
    symbol { 'TTF' }
    description { 'SECP256K1/multisig (Source Code) is a script which allows a group of users to sign a single transaction.' }
    verified { false }
  end
end
