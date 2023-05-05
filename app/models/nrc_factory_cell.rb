class NrcFactoryCell < ApplicationRecord
  after_create :create_token_collection
  after_update :update_token_collection

  def nrc_721_factory_cell_type
    @nrc_721_factory_cell_type ||= TypeScript.where(code_hash: code_hash, hash_type: hash_type, args: args).last
  end

  def type_script
    if defined?(@type_script)
      @type_script
    else
      @type_script = TypeScript.find_or_create_by(hash_type: hash_type, code_hash: code_hash, args: args)
    end
  end

  def first_cell
    @first_cell ||= CellOutput.where(type_script_id: type_script.id).first if type_script
  end

  def last_cell
    @last_cell ||= CellOutput.where(type_script_id: type_script.id).last if type_script
  end

  def token_collection
    @token_collection ||= create_token_collection
  end

  def create_token_collection
    TokenCollection.create_with(
      creator_id: last_cell&.address_id,
      name: name,
      symbol: symbol,
      icon_url: base_token_uri
    ).find_or_create_by(
      standard: "nrc721",
      type_script_id: type_script&.id
    )
  end

  def update_token_collection
    token_collection.update(
      name: name,
      symbol: symbol,
      creator_id: last_cell&.address_id,
      type_script_id: type_script&.id,
      icon_url: base_token_uri
    )
  end

  def parse_data
    factory_data = CellOutput.where(
      type_script_id: nrc_721_factory_cell_type.id,
      cell_type: "nrc_721_factory"
    ).last&.data
    return if factory_data.blank?

    parsed_factory_data = CkbUtils.parse_nrc_721_factory_data(factory_data)
    update(name: parsed_factory_data.name,
           symbol: parsed_factory_data.symbol,
           base_token_uri: parsed_factory_data.base_token_uri,
           extra_data: parsed_factory_data.extra_data)
    udts = Udt.where(nrc_factory_cell_id: id)
    udts.each do |udt|
      udt_account = UdtAccount.where(udt_id: udt.id, udt_type: "nrc_721_token").first
      udt_account.update(
        full_name: parsed_factory_data.name,
        symbol: parsed_factory_data.symbol
      )
      udt.update(
        full_name: parsed_factory_data.name,
        symbol: parsed_factory_data.symbol,
        icon_file: "#{parsed_factory_data.base_token_uri}/#{udt_account.nft_token_id}"
      )

      # update udt transaction page cache
      ckb_transactions = udt.ckb_transactions.select(:id, :tx_hash, :block_id, :block_number, :block_timestamp, :is_cellbase, :updated_at).recent.page(1).per(CkbTransaction.default_per_page)
      Rails.cache.delete(ckb_transactions.cache_key)
    end
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
