class Contract < ApplicationRecord
end

# == Schema Information
#
# Table name: contracts
#
#  id            :bigint           not null, primary key
#  code_hash     :binary
#  hash_type     :string
#  deployed_args :string
#  role          :string
#  name          :string
#  symbol        :string
#  verified      :boolean          default(FALSE)
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_contracts_on_code_hash  (code_hash)
#  index_contracts_on_hash_type  (hash_type)
#  index_contracts_on_name       (name)
#  index_contracts_on_role       (role)
#  index_contracts_on_symbol     (symbol)
#  index_contracts_on_verified   (verified)
#
