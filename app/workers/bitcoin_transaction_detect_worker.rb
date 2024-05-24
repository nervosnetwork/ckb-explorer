class BitcoinTransactionDetectWorker
  include Sidekiq::Worker
  sidekiq_options queue: "bitcoin"

  BITCOIN_RPC_BATCH_SIZE = 30

  attr_accessor :block, :txids, :rgbpp_cell_ids, :btc_time_cell_ids

  def perform(number)
    @block = Block.find_by(number:)
    return unless @block

    @txids = [] # bitcoin txids
    @rgbpp_cell_ids = [] # rgbpp cells
    @btc_time_cell_ids = [] # btc time cells

    ApplicationRecord.transaction do
      block.ckb_transactions.each do |transaction|
        inputs = transaction.input_cells
        outputs = transaction.cell_outputs
        (inputs + outputs).each { collect_rgb_ids(_1) }
      end

      # batch fetch bitcoin raw transactions
      cache_raw_transactions!
      # import rgbpp cells
      @rgbpp_cell_ids.each { ImportRgbppCellJob.perform_now(_1) }
      # import btc time cells
      @btc_time_cell_ids.each { ImportBtcTimeCellJob.perform_now(_1) }
      # update bitcoin annotation
      build_bitcoin_annotations!
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

  def build_bitcoin_annotations!
    annotations = []

    @block.ckb_transactions.each do |transaction|
      next unless BitcoinTransfer.exists?(ckb_transaction_id: transaction.id)

      leap_direction, transfer_step = annotation_workflow_attributes(transaction)
      tags = annotation_tags(transaction)
      annotations << { ckb_transaction_id: transaction.id, leap_direction:, transfer_step:, tags: }
    end

    BitcoinAnnotation.upsert_all(annotations, unique_by: [:ckb_transaction_id]) if annotations.present?
  end

  def annotation_workflow_attributes(transaction)
    sort_types = ->(lock_types) {
      lock_types.sort! do |a, b|
        if a && b
          a <=> b
        else
          a ? -1 : 1
        end
      end
    }

    input_lock_types = transaction.input_cells.map { _1.bitcoin_transfer&.lock_type }.uniq
    sort_types.call(input_lock_types)

    output_lock_types = transaction.cell_outputs.map { _1.bitcoin_transfer&.lock_type }.uniq
    sort_types.call(output_lock_types)

    if input_lock_types == ["rgbpp"]
      if output_lock_types == ["rgbpp"]
        ["withinBTC", "isomorphic"]
      elsif [["btc_time", "rgbpp"], ["btc_time"]].include?(output_lock_types)
        ["in", "isomorphic"]
      end
    elsif input_lock_types == ["btc_time"]
      ["in", "unlock"]
    end
  end

  def annotation_tags(transaction)
    cell_output_ids = transaction.input_cell_ids + transaction.cell_output_ids
    lock_types = BitcoinTransfer.where(cell_output_id: cell_output_ids).pluck(:lock_type)
    lock_types.compact.uniq
  end
end
