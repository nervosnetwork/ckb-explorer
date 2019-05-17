module CkbSync
  class AuthenticSync
    class << self
      def sync_node_data(sync_numbers)
        worker_args = Concurrent::Array.new
        ivars =
          sync_numbers.each_slice(10).map do |numbers|
            worker_args_producer = CkbSync::DataSyncWorkerArgsProducer.new(worker_args)
            worker_args_producer.async.produce_worker_args(numbers)
          end

        worker_args_consumer = CkbSync::DataSyncWorkerArgsConsumer.new(worker_args, "CheckBlockWorker", "authentic_sync", "current_authentic_sync_round")
        worker_args_consumer.consume_worker_args(ivars)

        CkbSync::Persist.update_ckb_transaction_info_and_fee
      end
    end
  end
end
