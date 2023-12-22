class CkbTransactionsSerializer
  include FastJsonapi::ObjectSerializer

  attributes :is_cellbase

  attribute :transaction_hash do |object|
    object.tx_hash.to_s
  end

  attribute :block_number do |object|
    object.block_number.to_s
  end

  attribute :block_timestamp do |object|
    object.block_timestamp.to_s
  end

  attribute :display_inputs_count do |object|
    object.display_inputs.count
  end

  attribute :display_outputs_count do |object|
    object.display_outputs.count
  end

  attribute :display_inputs do |object, params|
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
    if params && params[:previews] && params[:address].present?
      object.income(params[:address])
    end
  end

  attribute :created_at do |object|
    object.created_at.to_s
  end

  attribute :create_timestamp do |object|
    (object.created_at.to_f * 1000).to_i.to_s
  end
end
