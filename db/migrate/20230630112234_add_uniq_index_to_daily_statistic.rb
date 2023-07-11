class AddUniqIndexToDailyStatistic < ActiveRecord::Migration[7.0]
  def change
    remove_index :daily_statistics, :created_at_unixtimestamp
    add_index :daily_statistics, :created_at_unixtimestamp, unique: true
  end
end
