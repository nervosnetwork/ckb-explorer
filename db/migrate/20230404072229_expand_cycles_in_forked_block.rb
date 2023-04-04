class ExpandCyclesInForkedBlock < ActiveRecord::Migration[7.0]
  def up
    change_column :forked_blocks, :cycles, :bigint
    # Ex:- change_column("admin_users", "email", :string, :limit =>25)
  end

  def down
    change_column :forked_blocks, :cycles, :integer
    # Ex:- change_column("admin_users", "email", :string, :limit =>25)
  end
end
