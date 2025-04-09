class AddTotalLiquidityToFiberStatistics < ActiveRecord::Migration[7.0]
  def change
    rename_column :fiber_statistics, :total_liquidity, :total_capacity
    add_column :fiber_statistics, :total_liquidity, :jsonb
  end
end
