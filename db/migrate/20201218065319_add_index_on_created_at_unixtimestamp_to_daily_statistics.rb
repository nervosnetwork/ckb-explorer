class AddIndexOnCreatedAtUnixtimestampToDailyStatistics < ActiveRecord::Migration[6.0]
  def change
    add_index :daily_statistics, :created_at_unixtimestamp, order: { created_at_unixtimestamp: "DESC NULLS LAST" }
  end
end
