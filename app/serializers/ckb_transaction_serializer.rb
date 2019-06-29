class CkbTransactionSerializer
  include FastJsonapi::ObjectSerializer

  attributes :block_number, :block_timestamp, :transaction_fee, :version, :display_inputs, :display_outputs, :is_cellbase

  attribute :transaction_hash, &:tx_hash
end
