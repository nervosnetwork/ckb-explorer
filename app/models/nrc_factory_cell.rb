class NrcFactoryCell < ApplicationRecord
  after_create :create_token_collection

  def create_token_collection
    TokenCollection.find_or_create_by(
      standard: 'nrc721',
      name: name,
      symbol: symbol,
      type_script_id: TypeScript.find_by(hash_type: hash_type, code_hash: code_hash, args: args).id
    )
  end
end

# == Schema Information
#
# Table name: nrc_factory_cells
#
#  id             :bigint           not null, primary key
#  code_hash      :binary
#  hash_type      :string
#  args           :string
#  name           :string
#  symbol         :string
#  base_token_uri :string
#  extra_data     :string
#  verified       :boolean          default(FALSE)
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
# Indexes
#
#  index_nrc_factory_cells_on_code_hash_and_hash_type_and_args  (code_hash,hash_type,args) UNIQUE
#
