# notice:
#
class CkbTransactionSerializer
  include FastJsonapi::ObjectSerializer

  # for the tx_status,
  attributes :is_cellbase, :tx_status

  attribute :witnesses do |o|
    o.witnesses.order("index ASC")&.map(&:data) || []
  end

  attribute :cell_deps do |o|
    o.cell_dependencies.order("id asc").includes(:cell_output, :contracts).to_a.map(&:to_raw)
  end

  attribute :header_deps do |o|
    o.header_dependencies.map(&:header_hash)
  end

  attribute :detailed_message do |object|
    if object.tx_status.to_s == "rejected"
      object.detailed_message
    end
  end

  attribute :transaction_hash do |object|
    object.tx_hash.to_s
  end

  attribute :transaction_fee do |object|
    object.transaction_fee.to_s
  end

  attribute :block_number do |object|
    object.block_number.to_s
  end

  attribute :version do |object|
    object.version.to_s
  end

  attribute :block_timestamp do |object|
    object.block_timestamp.to_s
  end

  attribute :display_inputs do |object, params|
    display_cells = ActiveModel::Type::Boolean.new.cast(params[:display_cells])
    next [] unless display_cells

    cache_key = "display_inputs_previews_#{params[:previews].present?}_#{object.id}_#{object.inputs.cache_version}"
    Rails.cache.fetch(cache_key, expires_in: 1.day) do
      if params && params[:previews]
        object.display_inputs(previews: true)
      else
        object.display_inputs
      end
    end
  end

  attribute :display_outputs do |object, params|
    display_cells = ActiveModel::Type::Boolean.new.cast(params[:display_cells])
    next [] unless display_cells

    cache_key = "display_outputs_previews_#{params[:previews].present?}_#{object.id}_#{object.outputs.cache_version}"
    Rails.cache.fetch(cache_key, expires_in: 1.day) do
      if params && params[:previews]
        object.display_outputs(previews: true)
      else
        object.display_outputs
      end
    end
  end

  attribute :income do |object, params|
    if params && params[:previews] && params[:address_id].present?
      object.account_books.where(address_id: params[:address_id]).sum(:income)
    end
  end

  attribute :bytes do |object|
    UpdateTxBytesWorker.perform_async object.id if object.bytes.blank?
    object.bytes
  end
  attribute :largest_tx_in_epoch do |object|
    object.block&.epoch_statistic&.largest_tx_bytes
  end

  attribute :largest_tx do
    EpochStatistic.largest_tx_bytes
  end

  attribute :cycles do |object|
    object.cycles
  end

  attribute :max_cycles_in_epoch do |object|
    object.block&.epoch_statistic&.max_tx_cycles
  end

  attribute :max_cycles do
    EpochStatistic.max_tx_cycles
  end

  attribute :is_rgb_transaction do |object|
    object.rgb_transaction?
  end

  attribute :is_btc_time_lock do |object|
    object.btc_time_transaction?
  end

  attribute :rgb_txid do |object|
    object.rgb_txid
  end

  attribute :rgb_transfer_step do |object|
    object.transfer_step
  end
end
