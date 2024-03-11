class BitcoinTransactionSerializer
  include FastJsonapi::ObjectSerializer

  # for the tx_status,
  attributes :txid

  attribute :transaction_hash do |object|
    object.hash
  end

  attribute :ckb_transaction_hash do |object|
    object.ckb_transaction_hash
  end
end
