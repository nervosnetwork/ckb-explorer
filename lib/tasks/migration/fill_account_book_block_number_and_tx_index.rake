namespace :migration do
  desc "Usage: RAILS_ENV=production bundle exec rake migration:fill_account_book_block_number_and_tx_index[0,1000000]"
  task :fill_account_book_block_number_and_tx_index, %i[start_block end_block] => :environment do |_, args|
    ActiveRecord::Base.connection.execute("SET statement_timeout = 0")
    $missed_tx_ids = []
    (args[:start_block].to_i..args[:end_block].to_i).to_a.each do |block_number|
      puts block_number
      attrs = Set.new
      CkbTransaction.joins(:block).includes(:inputs, :outputs).where(block: { number: block_number }).where(is_cellbase: false).each do |tx|
        outputs = tx.outputs.pluck(:address_id, :capacity).group_by { |item| item[0] }.
          transform_values { |values| values.sum { |v| v[1] } }
        inputs = tx.inputs.pluck(:address_id, :capacity).group_by { |item| item[0] }.
          transform_values { |values| values.sum { |v| v[1] } }
        address_ids = (outputs.keys + inputs.keys).uniq
        exists = ensure_all_data_exists(address_ids, tx.id)
        if exists
          address_ids.each do |address_id|
            income = (outputs[address_id] || 0) - (inputs[address_id] || 0)
            attrs << { address_id:, ckb_transaction_id: tx.id, income:, block_number: tx.block_number, tx_index: tx.tx_index }
          end
        else
          $missed_tx_ids << tx.id
        end
      end
      AccountBook.upsert_all(attrs.to_a, unique_by: %i[address_id ckb_transaction_id]) if attrs.present?
    end

    puts $missed_tx_ids.join(",")
    puts "done"
  end
  def ensure_all_data_exists(address_ids, tx_id)
    data =
      address_ids.map do |address_id|
        { address_id:, ckb_transaction_id: tx_id }
      end
    query_conditions = data.map { |d| "(address_id = #{d[:address_id]} AND ckb_transaction_id = #{d[:ckb_transaction_id]})" }.join(" OR ")
    existing_records = AccountBook.where(query_conditions).pluck(:address_id, :ckb_transaction_id)
    data.map(&:values).to_set.subset?(existing_records.to_set)
  end
end
