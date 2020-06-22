class AddIssuerAddressToUdts < ActiveRecord::Migration[6.0]
  def change
    add_column :udts, :issuer_address, :binary
  end
end
