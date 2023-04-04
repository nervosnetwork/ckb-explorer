class AddVerifiedValueToContracts < ActiveRecord::Migration[7.0]
  def change
    Contract.all.each do |contract|
      contract.update verified: true
    end
  end
end
