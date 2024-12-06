class AddKnowledgeSizeToDailyStatistics < ActiveRecord::Migration[7.0]
  def change
    add_column :daily_statistics, :knowledge_size, :decimal, precision: 30
  end
end
