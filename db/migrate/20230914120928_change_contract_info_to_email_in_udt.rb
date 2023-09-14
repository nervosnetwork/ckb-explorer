class ChangeContractInfoToEmailInUdt < ActiveRecord::Migration[7.0]
  def change
    rename_column :udts, :contact_info, :email
  end
end
