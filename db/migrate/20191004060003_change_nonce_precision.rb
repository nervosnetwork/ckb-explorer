class ChangeNoncePrecision < ActiveRecord::Migration[6.0]
  def change
    reversible do |dir|
      dir.up do
        change_column :blocks, :nonce, :decimal, precision: 50, scale: 0, default: 0
        change_column :uncle_blocks, :nonce, :decimal, precision: 50, scale: 0, default: 0
        change_column :forked_blocks, :nonce, :decimal, precision: 50, scale: 0, default: 0
      end

      dir.down do
        change_column :blocks, :nonce, :decimal, precision: 30, scale: 0, default: 0
        change_column :uncle_blocks, :nonce, :decimal, precision: 30, scale: 0, default: 0
        change_column :forked_blocks, :nonce, :decimal, precision: 30, scale: 0, default: 0
      end
    end
  end
end
