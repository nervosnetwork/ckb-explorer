class BitcoinTransactionDetectWorker
  include Sidekiq::Worker
  sidekiq_options queue: "bitcoin"

  BITCOIN_RPC_BATCH_SIZE = 30

  attr_accessor :txids, :rgbpp_cell_ids, :btc_time_cell_ids

  def perform(block_id)
    block = Block.find_by(id: block_id)
    return unless block

    @txids = [] # bitcoin txids
    @rgbpp_cell_ids = [] # rgbpp cells
    @btc_time_cell_ids = [] # btc time cells

    ApplicationRecord.transaction do
      block.ckb_transactions.each do |transaction|
        transaction.cell_inputs.each do |cell_input|
          previous_cell_output = cell_input.previous_cell_output
          next unless previous_cell_output

          collect_rgb_ids(previous_cell_output)
        end

        transaction.cell_outputs.each do |cell_output|
          collect_rgb_ids(cell_output)
        end
      end

      # batch fetch bitcoin raw transactions
      cache_raw_transactions!
      # import rgbpp cells
      @rgbpp_cell_ids.uniq.each { ImportRgbppCellJob.perform_now(_1) }
      # import btc time cells
      @btc_time_cell_ids.uniq.each { ImportBtcTimeCellJob.perform_now(_1) }
      # update tags
      update_transaction_tags!(transaction)
    end
  end

  def collect_rgb_ids(cell_output)
    lock_script = cell_output.lock_script
    cell_output_id = cell_output.id

    if CkbUtils.is_rgbpp_lock_cell?(lock_script)
      txid, _out_index = CkbUtils.parse_rgbpp_args(lock_script.args)
      unless BitcoinTransfer.includes(:bitcoin_transaction).where(
        bitcoin_transactions: { txid: },
        bitcoin_transfers: { cell_output_id:, lock_type: "rgbpp" },
      ).exists?
        @rgbpp_cell_ids << cell_output_id
        @txids << txid
      end
    end

    if CkbUtils.is_btc_time_lock_cell?(lock_script)
      parsed_args = CkbUtils.parse_btc_time_lock_cell(lock_script.args)
      txid = parsed_args.txid
      unless BitcoinTransfer.includes(:bitcoin_transaction).where(
        bitcoin_transactions: { txid: },
        bitcoin_transfers: { cell_output_id:, lock_type: "btc_time" },
      ).exists?
        @btc_time_cell_ids << cell_output_id
        @txids << txid
      end
    end
  end

  def cache_raw_transactions!
    return if @txids.empty?

    get_raw_transactions = ->(txids) do
      payload = txids.map.with_index do |txid, index|
        { jsonrpc: "1.0", id: index + 1, method: "getrawtransaction", params: [txid, 2] }
      end
      response = HTTP.timeout(10).post(ENV["BITCOIN_NODE_URL"], json: payload)
      JSON.parse(response.to_s)
    end

    to_cache = {}
    not_cached = @txids.uniq.reject { Rails.cache.exist?(_1) }

    not_cached.each_slice(BITCOIN_RPC_BATCH_SIZE).each do |txids|
      get_raw_transactions.call(txids).each do |data|
        next if data && data["error"].present?

        txid = data.dig("result", "txid")
        to_cache[txid] = data
      end
    end

    Rails.cache.write_multi(to_cache, expires_in: 10.minutes) if to_cache.present?
  rescue StandardError => e
    Rails.logger.error "cache raw transactions(#{@txids.uniq}) failed: #{e.message}"
  end

  def update_transaction_tags!(transaction)
    transaction.tags ||= []

    cell_output_ids = transaction.input_ids + transaction.output_ids
    lock_types = BitcoinTransfer.where(cell_output_id: cell_output_ids).pluck(:lock_type)
    transaction.tags += lock_types.compact.uniq

    transaction.update!(tags: transaction.tags.uniq)
  end
end
