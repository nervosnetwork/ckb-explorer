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
