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

  attribute :display_inputs do |object, params|
    if params && params[:previews]
      if object.display_inputs_info.present?
        object.display_inputs_info(previews: true)
      else
        object.display_inputs(previews: true)
      end
    else
      object.display_inputs_info.presence || object.display_inputs
    end
  end

  attribute :display_outputs do |object, params|
    if params && params[:previews]
      if object.display_inputs_info.present?
        object.display_outputs_info(previews: true)
      else
        object.display_outputs(previews: true)
      end
    else
      if object.display_inputs_info.present?
        object.display_outputs_info
      else
        object.display_outputs
      end
    end
  end

  attribute :income do |object, params|
    if params && params[:previews] && params[:address].present?
      if object.tx_display_info.present?
        object.tx_display_info.income[params[:address].address_hash]
      else
        object.income(params[:address])
      end
    end
  end

end
