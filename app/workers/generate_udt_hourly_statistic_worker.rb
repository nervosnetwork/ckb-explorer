class GenerateUdtHourlyStatisticWorker
  include Sidekiq::Job

  def perform
    udt_types = %i[xudt xudt_compatible spore_cell did_cell]
    created_at_unixtimestamp = to_be_counted_date.beginning_of_day.to_i
    ActiveRecord::Base.connection.execute("SET statement_timeout = 0")
    Udt.where(udt_type: udt_types, published: true).find_each do |udt|
      puts "Generating statistics for #{udt.id}"
      UdtHourlyStatistic.upsert(
        {
          udt_id: udt.id,
          amount: calc_amount(udt),
          ckb_transactions_count: calc_ckb_transactions_count(udt),
          holders_count: calc_holders_count(udt),
          created_at_unixtimestamp:,
        },
        unique_by: %i[udt_id created_at_unixtimestamp],
      )
    end
    ActiveRecord::Base.connection.execute("RESET statement_timeout")
  rescue StandardError => e
    Rails.logger.error "Error occurred during GenerateUdtHourlyStatistic error: #{e.message}"
  end

  private

  def to_be_counted_date
    last_record = UdtHourlyStatistic.order(created_at_unixtimestamp: :desc).first
    if last_record
      Time.zone.at(last_record.created_at_unixtimestamp) + 1.day
    else
      Time.current.yesterday
    end
  end

  def calc_amount(udt)
    inputs_amount = 0
    outputs_amount = 0
    ckb_transaction_ids = udt.ckb_transactions.map(&:id)
    ckb_transaction_ids.each_slice(1000) do |ids|
      inputs_amount += CellOutput.where(consumed_by_id: ids).sum(:udt_amount)
      outputs_amount += CellOutput.where(ckb_transaction_id: ids).sum(:udt_amount)
    end
    [inputs_amount, outputs_amount].max
  end

  def calc_ckb_transactions_count(udt)
    udt.ckb_transactions.count
  end

  def calc_holders_count(udt)
    udt.udt_holder_allocations.sum("ckb_holder_count + btc_holder_count")
  end
end
