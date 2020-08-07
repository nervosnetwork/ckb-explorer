namespace :migration do
  desc "Usage: RAILS_ENV=production bundle exec rake migration:init_table_record_count"
  task init_table_record_count: :environment do
    ApplicationRecord.transaction do
      ActiveRecord::Base.connection.execute('LOCK blocks IN ACCESS EXCLUSIVE MODE')
      TableRecordCount.create(table_name: "blocks", count: Block.count)
      TableRecordCount.create(table_name: "ckb_transactions", count: CkbTransaction.count)
    end

    puts "done"
  end
end
