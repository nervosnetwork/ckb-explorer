module CkbSync
  class InauthenticSync
    class << self
      def sync_node_data(sync_numbers)
        worker_args = Concurrent::Array.new
        ivars =
          sync_numbers.each_slice(10).map do |numbers|
            worker_args_producer = CkbSync::DataSyncWorkerArgsProducer.new(worker_args)
            worker_args_producer.async.produce_worker_args(numbers)
          end

        worker_args_consumer = CkbSync::DataSyncWorkerArgsConsumer.new(worker_args, "SaveBlockWorker", "inauthentic_sync", "current_inauthentic_sync_round")
        worker_args_consumer.consume_worker_args(ivars)
      end
    end
  end
end
