class AddImplicitToCellDependency < ActiveRecord::Migration[7.0]
  def change
    add_column :cell_dependencies, :implicit, :boolean, default: true, null: false
    # Ex:- add_column("admin_users", "username", :string, :limit =>25, :after => "email")
  end
end
