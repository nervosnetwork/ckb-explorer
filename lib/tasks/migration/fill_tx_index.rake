namespace :migration do
  desc "Usage: RAILS_ENV=production bundle exec rake migration:fill_tx_index"
  task fill_tx_index: :environment do
    $retry_ids = Set.new
    @api = CKB::API.new(host: ENV["CKB_NODE_URL"],
                        timeout_config: {
                          open_timeout: 1, read_timeout: 3,
                          write_timeout: 1
                        })
    first_tx = CkbTransaction.tx_committed.where(tx_index: nil).order("block_number asc").select(:block_number).first
    last_tx = CkbTransaction.tx_committed.where(tx_index: nil).order("block_number desc").select(:block_number).first

    (first_tx.block_number..last_tx.block_number).to_a.each_slice(100).to_a.each do |range|
      fill_missed_tx_index(range, 0)
    end; nil

    puts "retry IDS:"
    puts $retry_ids.join(",")
    puts "done"
  end

  def fill_missed_tx_index(range, retry_count)
    request_body =
      range.map do |number|
        ["get_block_by_number", number]
      end
    response = @api.batch_request(*request_body)
    attrs = []
    response.each do |r|
      r[:transactions].each_with_index do |tx, index|
        attrs << { tx_hash: tx[:hash], tx_status: "committed", tx_index: index }
      end
    end; nil
    CkbTransaction.upsert_all(attrs, unique_by: %i[tx_status tx_hash])
  rescue StandardError => _e
    retry_count += 1
    if retry_count > 2
      $retry_ids << range.first
    else
      fill_missed_tx_index(range, retry_count)
    end
  end
end
