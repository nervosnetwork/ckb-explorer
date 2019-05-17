module CkbSync
  class AuthenticSync
    class << self
      def sync_node_data
        authentic_tip_block_number = SyncInfo.local_authentic_tip_block_number
        inauthentic_tip_block_number = SyncInfo.local_inauthentic_tip_block_number
        from = authentic_tip_block_number + 1
        to = inauthentic_tip_block_number - ENV["BLOCK_SAFETY_INTERVAL"].to_i

        return if should_break?(from, to)

        generate_sync_log(from, to)

        worker_args = Concurrent::Array.new
        ivars =
          (from..to).each_slice(10).map do |numbers|
            worker_args_producer = CkbSync::DataSyncWorkerArgsProducer.new(worker_args)
            worker_args_producer.async.produce_worker_args(numbers)
          end

        worker_args_consumer = CkbSync::DataSyncWorkerArgsConsumer.new(worker_args, "CheckBlockWorker", "authentic_sync", "current_authentic_sync_round")
        worker_args_consumer.consume_worker_args(ivars)

        CkbSync::Persist.update_ckb_transaction_info_and_fee
      end

      def generate_sync_log(latest_from, latest_to)
        sync_infos =
          (latest_from..latest_to).map do |number|
            SyncInfo.new(name: "authentic_tip_block_number", value: number, status: "syncing")
          end

        SyncInfo.import sync_infos, batch_size: 1500, on_duplicate_key_ignore: true
      end

      def should_break?(latest_from, latest_to)
        return true if latest_to < 0 || latest_from >= latest_to

        latest_uuid = SecureRandom.uuid
        cached_current_round = current_sync_round(latest_from, latest_to, latest_uuid)
        current_from = cached_current_round[:from]
        current_to = cached_current_round[:to]
        current_uuid = cached_current_round[:uuid]
        current_round_range = current_from..current_to
        latest_round_range = latest_from..latest_to

        return false if (current_round_range).eql?(latest_round_range) && current_uuid == latest_uuid

        (current_round_range).overlaps?(latest_round_range)
      end

      def current_sync_round(from, to, uuid)
        Rails.cache.fetch("current_authentic_sync_round", expires_in: 5.minutes) do
          { from: from, to: to, uuid: uuid }
        end
      end
    end
  end
end