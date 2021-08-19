class ChangeAddressBalanceDefaultValueToZero < ActiveRecord::Migration[6.1]
  def change
    change_column_default :addresses, :balance, 0
  end
end
