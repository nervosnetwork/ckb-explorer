class CkbTransactionSerializer
  include FastJsonapi::ObjectSerializer

  attributes :block_number, :block_timestamp, :version, :display_inputs, :display_outputs

  attribute :transaction_hash do |object|
    object.tx_hash
  end

  attribute :transaction_fee do |object|
    Shannon.new(object.transaction_fee).to_ckb
  end
end
