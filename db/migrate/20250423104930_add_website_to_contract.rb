class AddWebsiteToContract < ActiveRecord::Migration[7.0]
  def change
    add_column :contracts, :website, :string
  end
end
