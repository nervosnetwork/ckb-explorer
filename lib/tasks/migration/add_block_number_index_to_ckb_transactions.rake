namespace :migration do
  desc "Usage: RAILS_ENV=production bundle exec rake migration:add_block_number_index_to_ckb_transactions"
  task add_block_number_index_to_ckb_transactions: :environment do
    table_name = :ckb_transactions
    column_name = :block_number
    index_name = "index_#{table_name}_on_#{column_name}".to_sym

    unless ActiveRecord::Base.connection.index_exists?(table_name, :column_name)
      ActiveRecord::Migration.suppress_messages do
        ActiveRecord::Base.connection.add_index table_name, column_name, 
                                                  name: index_name
      end
      Rails.logger.info "Successfully created index #{index_name} on #{table_name}.#{column_name}"
    else
      Rails.logger.info "Index #{index_name} already exists on #{table_name}.#{column_name}"
    end
  rescue StandardError => e
    Rails.logger.error "Failed to create index #{index_name}: #{e.message}"
  end
end
