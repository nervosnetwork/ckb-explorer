class AddContactInfoToUdts < ActiveRecord::Migration[7.0]
  def change
    add_column :udts, :contact_info, :string
  end
end
