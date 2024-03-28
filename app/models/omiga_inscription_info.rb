class OmigaInscriptionInfo < ApplicationRecord
  belongs_to :udt, optional: true

  enum mint_status: { minting: 0, closed: 1, rebase_start: 2 }
end

# == Schema Information
#
# Table name: omiga_inscription_infos
#
#  id                 :bigint           not null, primary key
#  code_hash          :binary
#  hash_type          :string
#  args               :string
#  decimal            :decimal(, )
#  name               :string
#  symbol             :string
#  udt_hash           :string
#  expected_supply    :decimal(, )
#  mint_limit         :decimal(, )
#  mint_status        :integer
#  udt_id             :bigint
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  type_hash          :binary
#  pre_udt_hash       :binary
#  is_repeated_symbol :boolean          default(FALSE)
#
# Indexes
#
#  index_omiga_inscription_infos_on_udt_hash  (udt_hash) UNIQUE
#
