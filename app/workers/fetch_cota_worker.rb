class FetchCotaWorker
  include Sidekiq::Worker
  def perform(block_number, check_aggregator_info = true)
    # synchronize historical data, ignore cota aggregator info check
    if check_aggregator_info && !cota_syning?
      raise "COTA Sync Failed!!!"
    end

    data = CotaAggregator.instance.get_transactions_by_block_number(block_number)
    if data["block_number"] < block_number
      return FetchCotaWorker.perform_in(5.minutes, block_number)
    end

    data["transactions"].each do |t|
      puts t.inspect
      collection = find_or_create_collection(t)
      item = find_or_create_item(collection, t)
      action =
        case (t["type"] || t["tx_type"]) # compatible with old field name
        when "mint"
          "mint"
        when "transfer"
          "normal"
        end
      tx = CkbTransaction.find_by tx_hash: t["tx_hash"]
      tt = TokenTransfer.find_or_initialize_by item_id: item.id, transaction_id: tx.id
      unless tt.persisted?
        from_id = Address.find_or_create_by_address_hash(t["from"])
        to_id = Address.find_or_create_by_address_hash(t["to"])
        tt.update!(from_id:, to_id:, action:)
      end
    end
  end

  def find_or_create_collection(t)
    cota_id = t["cota_id"]
    c = TokenCollection.
      find_or_initialize_by(standard: "cota", sn: cota_id)
    unless c.persisted?
      info = CotaAggregator.instance.get_define_info(cota_id)
      issuer = CotaAggregator.instance.get_issuer_info_by_cota_id(cota_id)
      cell_id = fetch_mint_first_nft_cell_id(cota_id)

      addr = Address.cached_find issuer["lock_hash"]
      c.update(
        name: info["name"],
        symbol: info["symbol"],
        description: info["description"],
        creator_id: addr.id,
        icon_url: info["image"],
        cell_id:,
      )
      c.save!
    end
    c
  end

  def find_or_create_item(collection, t)
    to_id = Address.find_or_create_by_address_hash t["to"]
    i = collection.items.find_or_initialize_by(token_id: t["token_index"].hex)
    i.update! owner_id: to_id
    i
  end

  def fetch_mint_first_nft_cell_id(cota_id)
    page = 0
    mint_tx =
      loop do
        res = CotaAggregator.instance.get_history_transactions(cota_id:, token_index: 0, page:, page_size: 20)
        mint_tx =
          res["transactions"].filter do |tx|
            tx["tx_type"] == "mint"
          end
        break mint_tx if mint_tx.length == 1

        page += 1
      end
    CellOutput.where(tx_hash: mint_tx.first.fetch("tx_hash")).first&.id
  rescue StandardError => e
    Rails.logger.error "cota_id: #{cota_id}, detail: #{e.inspect}"
    nil
  end

  private

  def cota_syning?
    res = CotaAggregator.instance.get_aggregator_info
    [res["indexer_block_number"], res["node_block_number"], res["syncer_block_number"]].uniq.size == 1
  end
end
