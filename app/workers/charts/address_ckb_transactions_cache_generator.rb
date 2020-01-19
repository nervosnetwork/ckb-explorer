class AddressCkbTransactionsCacheGenerator
  include Sidekiq::Worker

  def perform(transaction_ids)
    $redis.with do |conn|
      conn.pipelined do
        CkbTransaction.where(id: transaction_ids).each do |transaction|
          transaction.addresses.distinct.each do |address|
            address.add_ckb_transaction_to_cache(transaction, conn)
          end
        end
      end
    end
  end
end
