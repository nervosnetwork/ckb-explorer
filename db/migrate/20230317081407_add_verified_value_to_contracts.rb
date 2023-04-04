class AddVerifiedValueToContracts < ActiveRecord::Migration[7.0]
  def change
    Contract.update_all verified: true
  end
end
