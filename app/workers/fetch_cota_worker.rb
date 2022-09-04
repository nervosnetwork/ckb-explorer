class FetchCotaWorker 
  include Sidekiq::Worker
  def perform(block_number)
    data = CotaAggregator.instance.get_transactions_by_block_number(block_number)
    if data['block_number'] < block_number
      return FetchCotaWorker.perform_in(5.minutes, block_number)
    end
    data['transactions'].each do |t|
      collection = find_or_create_collection(t)
      item = find_or_create_item(collection, t)
      type = case t['type']
      when 'mint'
        'mint'
      when 'transfer'
        'normal'
      end
      tx = CkbTransaction.find_by tx_hash: t['tx_hash']
      t = TokenTransfer.find_or_initialize_by item_id: item.id, transaction_id: tx.id
      unless t.persisted?
        from = Address.find_by_address_hash(t['from'])
        to = Address.find_by_address_hash(t['to'])
        t.update(from: from, to: to, type: type)
      end
    end
  end

  def find_or_create_collection(t)
    cota_id = t['cota_id']
    c = TokenCollection
      .find_or_initialize_by(standard: 'cota', sn: cota_id)
    unless c.persisted?
      info = CotaAggregator.instance.get_define_info(cota_id)
      c.update(
        name: info['name'],
        symbol: info['symbol'],
        description: info['description'],
        icon_url: info['image']
      )
      c.save
    end
    c
  end

  def find_or_create_item(collection, t)
    to = Address.find_by_address_hash t['to']
    i = collection.items.find_or_create_by(token_id: t['token_index'].hex)
    i.update owner: to
    i
  end
end
