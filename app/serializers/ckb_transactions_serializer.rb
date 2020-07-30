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
    params && params[:previews] ? object.display_inputs(previews: true) : object.display_inputs
  end

  attribute :display_outputs do |object, params|
    params && params[:previews] ? object.display_outputs(previews: true) : object.display_outputs
  end

  attribute :income do |object, params|
    params && params[:previews] && params[:address] ? object.income(params[:address]) : nil
  end
end
