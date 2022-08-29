class AddNFTTokenIdToUdtAccount < ActiveRecord::Migration[6.1]
  def change
    add_column :udt_accounts, :nft_token_id, :string
  end
end
