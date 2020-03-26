class AddUdtReferenceToUdtAccount < ActiveRecord::Migration[6.0]
  def change
    add_belongs_to :udt_accounts, :udt, index: true
  end
end
