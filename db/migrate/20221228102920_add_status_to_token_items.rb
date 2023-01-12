class AddStatusToTokenItems < ActiveRecord::Migration[7.0]
  def change
    add_column :token_items, :status, :integer, default: 1
  end
end
