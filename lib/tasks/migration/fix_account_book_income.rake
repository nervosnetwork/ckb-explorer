namespace :migration do
  desc "Usage: RAILS_ENV=production bundle exec rake migration:fix_account_book_income[0,1000000]"
  task :fix_account_book_income, %i[start_block end_block] => :environment do |_, args|
    (args[:start_block].to_i..args[:end_block].to_i).to_a.each_slice(1000).each do |range|
      block_numbers = AccountBook.where("block_number >= ? and block_number <= ?", range[0], range[-1]).
        select(:block_number, :address_id).
        group(:block_number, :address_id).
        having("COUNT(*) > 1").
        distinct.
        pluck(:block_number)
      attrs = Set.new
      CkbTransaction.joins(:block).includes(:inputs, :outputs).where(block: { number: block_numbers }).each do |tx|
        outputs = tx.outputs.pluck(:address_id, :capacity).group_by { |item| item[0] }.
          transform_values { |values| values.sum { |v| v[1] } }
        inputs = tx.inputs.pluck(:address_id, :capacity).group_by { |item| item[0] }.
          transform_values { |values| values.sum { |v| v[1] } }
        address_ids = (outputs.keys + inputs.keys).uniq
        address_ids.each do |address_id|
          income = (outputs[address_id] || 0) - (inputs[address_id] || 0)
          attrs << { address_id:, ckb_transaction_id: tx.id, income: }
        end
      end
      AccountBook.upsert_all(attrs.to_a, unique_by: %i[address_id ckb_transaction_id]) if attrs.present?
    end

    puts "done"
  end
end
