class TokenTransferDetectWorker
  include Sidekiq::Worker

  def perform(tx_id)
    tx = CkbTransaction.includes(:cell_outputs, cell_inputs: :previous_cell_output).find tx_id
    return unless tx

    @lock = Redis::Lock.new("token_transfer_#{tx_id}", expiration: 180, timeout: 30)
    @lock.lock do
      source_tokens = {}
      source_collections = []

      tx.cell_inputs.each do |input|
        if input.cell_type.in?(%w(m_nft_token nrc_721_token))
          cell = input.previous_cell_output
          type_script = input.type_script

          source_tokens[type_script.id] = cell if cell && type_script
        end
      end

      tx.cell_outputs.each do |output|
        if output.cell_type.in?(%w(m_nft_token nrc_721_token))
          type_script = output.type_script
          item = find_or_create_item(output, type_script)
          attrs = {
            item: item,
            transaction_id: tx.id,
            action: :normal,
            to_id: output.address_id
          }

          if source_tokens[type_script.id]
            # this is a transfer event
            attrs[:from_id] = source_tokens[type_script.id].address_id
          else
            # this is a mint event
            attrs[:action] = :mint
          end
          transfer = TokenTransfer.find_or_create_by!(attrs)
          source_tokens.delete(type_script.id)
        end
      end
      # remaining source token has no correspond output,
      # so they are destruction.
      source_tokens.each do |type_script_id, cell|
        item = TokenItem.find_by type_script_id: type_script_id
        TokenTransfer.transaction do
          t = TokenTransfer.
            create_with(action: :destruction, from_id: cell.address_id).
            find_or_create_by(item_id: item.id, transaction_id: tx.id)

          item.update status: :burnt
        end
      end
    end
  end

  def find_or_create_item(cell, type_script)
    coll = find_or_create_collection(cell, type_script)
    return unless coll

    item = TokenItem.find_or_initialize_by(type_script_id: type_script.id)
    item.collection = coll
    if item.cell
      if item.cell.block_timestamp < cell.block_timestamp
        item.cell = cell
      end
    else
      item.cell = cell
    end
    item.owner_id = item.cell.address_id
    item.token_id =
      case cell.cell_type
         when "m_nft_token"
           type_script.args[50..-1].hex
         when "nrc_721_token"
           type_script.args[132..-1].hex
      end
    item.save!
    item
  end

  def find_or_create_collection(cell, type_script)
    case cell.cell_type
    when "nrc_721_token"
      find_or_create_nrc_721_collection(cell, type_script)
    when "m_nft_token"
      find_or_create_m_nft_collection(cell, type_script)
    end
  end

  def find_or_create_nrc_721_collection(cell, type_script)
    factory_cell = CkbUtils.parse_nrc_721_args(type_script.args)
    nrc_721_factory_cell = NrcFactoryCell.find_or_create_by(code_hash: factory_cell.code_hash, hash_type: factory_cell.hash_type, args: factory_cell.args)

    if nrc_721_factory_cell.name.blank? || nrc_721_factory_cell.symbol.blank?
      nrc_721_factory_cell.parse_data
    end

    coll = TokenCollection.find_or_create_by(
      standard: "nrc721",
      type_script: nrc_721_factory_cell.type_script
    )

    if coll.cell_id.blank? || (coll.cell_id < nrc_721_factory_cell.id)
      coll.update(
        cell_id: nrc_721_factory_cell.id,
        symbol: nrc_721_factory_cell.symbol.to_s[0, 16],
        name: nrc_721_factory_cell.name,
        icon_url: nrc_721_factory_cell.base_token_uri
      )
    end
    coll
  end

  def find_or_create_m_nft_collection(cell, type_script)
    m_nft_class_type = TypeScript.create_with(hash_type: "type").find_or_create_by!(
      code_hash: CkbSync::Api.instance.token_class_script_code_hash,
      args: type_script.args[0..49]
    )
    coll = TokenCollection.find_or_create_by(
      standard: "m_nft",
      type_script_id: m_nft_class_type.id,
      sn: m_nft_class_type.script_hash
    )
    m_nft_class_cell = m_nft_class_type.cell_outputs.last
    if m_nft_class_cell.present? && (coll.cell_id.blank? || (coll.cell_id < m_nft_class_cell.id))
      parsed_class_data = CkbUtils.parse_token_class_data(m_nft_class_cell.data)
      coll.cell_id = m_nft_class_cell.id
      coll.icon_url = parsed_class_data.renderer
      coll.name = parsed_class_data.name
      coll.description = parsed_class_data.description
      coll.save
    end
    coll
  end
end
