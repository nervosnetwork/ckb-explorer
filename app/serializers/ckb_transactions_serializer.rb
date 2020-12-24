class CkbTransactionsSerializer
  include FastJsonapi::ObjectSerializer

  attributes :is_cellbase

  attribute :transaction_hash, &:tx_hash

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
      if object.display_inputs_info.present?
        object.display_inputs_info
      else
        object.display_inputs
      end
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
    params && params[:previews] && params[:address] ? object.income(params[:address]) : nil
  end
end
