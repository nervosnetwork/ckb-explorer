class CkbTransactionSerializer
  include FastJsonapi::ObjectSerializer

  attributes :block_number, :block_timestamp, :transaction_fee, :version, :display_inputs, :display_outputs, :is_cellbase

  attribute :transaction_hash, &:tx_hash

  attribute :display_inputs do |object, params|
    params && params[:previews] ? object.display_inputs(previews: true) : object.display_inputs
  end

  attribute :display_outputs do |object, params|
    params && params[:previews] ? object.display_outputs(previews: true) : object.display_outputs
  end
end
