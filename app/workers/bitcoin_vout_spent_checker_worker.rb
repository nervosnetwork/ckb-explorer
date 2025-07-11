class BitcoinVoutSpentCheckerWorker
  include Sidekiq::Job
  sidekiq_options retry: 0, queue: :bitcoin

  ZERO_TXID = "0000000000000000000000000000000000000000000000000000000000000000".freeze

  def perform
    unspent_outpoints.each do |txid, index|
      fallback_networks = ENV["CKB_NET_MODE"] == CKB::MODE::MAINNET ? [:mainnet] : %i[testnet signet]
      fallback_networks.each do |network|
        result = check_outspent(txid, index, network: network)
        break if %i[spent unspent].include?(result)
      end
    end
  end

  def unspent_outpoints
    desired_limit = ENV["CKB_NET_MODE"] == CKB::MODE::MAINNET ? 166 : 2000
    vouts = BitcoinVout.includes(:bitcoin_transaction).without_op_return.where(consumed_by_id: nil).order(id: :asc).limit(desired_limit * 2)
    if (last_id = $redis.get("btc:vout:last_request_id")).present?
      vouts = vouts.where("id > ?", last_id.to_i)
    end

    outpoints = []
    vout_ids = []

    vouts.each do |vout|
      key = [vout.bitcoin_transaction.txid, vout.index]
      next if outpoints.include?(key)

      outpoints << key
      vout_ids << vout.id
      break if outpoints.size >= desired_limit
    end

    $redis.set("btc:vout:last_request_id", vout_ids.max)
    outpoints
  end

  def check_outspent(txid, index, network:)
    cache_key = "unisat:#{network}:tx:#{txid}"
    vouts = Rails.cache.read(cache_key)
    if vouts.nil?
      vouts = fetch_unisat_vouts(txid, network)
      Rails.cache.write(cache_key, vouts, expires_in: 30.minutes) if vouts.present?
    end

    return :not_found if vouts.nil?

    out = vouts.detect { |o| o["vout"] == index }
    spent_txid = out&.dig("txidSpent")

    if spent_txid.present? && spent_txid != ZERO_TXID
      resolve_binding_status(spent_txid, txid, index)
      Rails.logger.info("Unisat: #{txid}:#{index} on #{network} => spent => #{spent_txid}")
      return :spent
    end

    Rails.logger.info("Unisat: #{txid}:#{index} on #{network} => unspent")
    :unspent
  rescue StandardError => e
    Rails.logger.error("check_outspent failed #{txid}:#{index} on #{network} - #{e.class}: #{e.message}")
    :unknown
  end

  def fetch_unisat_vouts(txid, network)
    # testnet: 10 RPS, 864000/day
    # mainnet: 5 RPS, 2000/day
    host = ENV.fetch("UNISAT_#{network.to_s.upcase}_HOST", nil)
    token = ENV.fetch("UNISAT_#{network.to_s.upcase}_TOKEN", nil)
    headers = { "accept" => "application/json", "Authorization" => "Bearer #{token}" }

    all = []
    cursor = 0
    size = 1000

    loop do
      url = "#{host}/v1/indexer/tx/#{txid}/outs?cursor=#{cursor}&size=#{size}"
      response = HTTP.timeout(60).headers(headers).get(url)
      sleep(network == :mainnet ? 0.4 : 0.2)

      body = JSON.parse(response.body.to_s)
      if body["code"] != 0 || !body["data"].is_a?(Array)
        # Rails.logger.warn("Unisat error #{txid} on #{network}: #{body['msg']}")
        return nil
      end

      all += body["data"]
      break if body["data"].size < size

      cursor += size
    end

    all
  rescue StandardError => e
    Rails.logger.error("fetch_unisat_vouts failed: #{txid} on #{network} - #{e.class}: #{e.message}")
    nil
  end

  def resolve_binding_status(consumed_txid, txid, index)
    consumed_by = find_consumed_by_transaction(consumed_txid)
    return unless consumed_by

    bitcoin_vouts = BitcoinVout.includes(:bitcoin_transaction).
      where(
        bitcoin_transactions: { txid: },
        bitcoin_vouts: { index:, op_return: false },
      )
    related_cell_outputs = bitcoin_vouts.filter_map(&:cell_output)

    if related_cell_outputs.all?(&:live?)
      bitcoin_vouts.update_all(status: "binding")
    else
      bitcoin_vouts.each do |vout|
        next unless vout.cell_output
        next if vout.normal? || vout.unbound?

        status = vout.cell_output.dead? ? "normal" : "unbound"
        vout.update(consumed_by:, status:)
      end
    end
  end

  def find_consumed_by_transaction(txid)
    # check whether consumed_by has been synchronized
    consumed_by = BitcoinTransaction.find_by(txid:)
    unless consumed_by
      raw_tx = fetch_raw_transaction(txid)
      return nil unless raw_tx

      consumed_by = BitcoinTransaction.create!(
        txid: raw_tx["txid"],
        tx_hash: raw_tx["hash"],
        time: raw_tx["time"],
        block_hash: raw_tx["blockhash"],
        block_height: 0,
      )
    end
    consumed_by
  end

  def fetch_raw_transaction(txid)
    data = Rails.cache.read(txid)
    data ||= Bitcoin::Rpc.instance.getrawtransaction(txid, 2)
    Rails.cache.write(txid, data, expires_in: 10.minutes) unless Rails.cache.exist?(txid)
    data["result"]
  rescue StandardError => e
    Rails.logger.error "get bitcoin raw transaction #{txid} failed: #{e}"
    nil
  end
end
