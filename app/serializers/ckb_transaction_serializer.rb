# notice:
# this class would serialize 2 models:  CkbTransaction and PoolTransactionEntry
#
class CkbTransactionSerializer
  include FastJsonapi::ObjectSerializer


  # for the tx_status,
  # CkbTransaction will always be "commited"
  # PoolTransactionEntry will give: 0, 1, 2, 3
  attributes :is_cellbase, :witnesses, :cell_deps, :header_deps, :tx_status

  attribute :detailed_message do |object|
    if object.tx_status.to_s == "rejected"
      object.detailed_message
    else
      nil
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
      # if object.tx_display_info.present?
      #   object.tx_display_info.income[params[:address].address_hash]
      # else
        object.income(params[:address])
      # end
    end
  end

  attribute :bytes do |object|
    object.bytes
  end
end
