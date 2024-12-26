class GenerateUdtHourlyStatisticWorker
  include Sidekiq::Job

  def perform(datetime = nil)
    ActiveRecord::Base.connection.execute("SET statement_timeout = 0")
    start_time = to_be_counted_date(datetime)
    generate_statistics(start_time)
    ActiveRecord::Base.connection.execute("RESET statement_timeout")
  rescue StandardError => e
    Rails.logger.error "Error occurred during GenerateUdtHourlyStatistic error: #{e.message}"
  end

  private

  def to_be_counted_date(datetime)
    last_record = UdtHourlyStatistic.order(created_at_unixtimestamp: :desc).first
    if last_record
      Time.zone.at(last_record.created_at_unixtimestamp) + 1.day
    else
      datetime.is_a?(String) ? Time.zone.parse(datetime) : Time.current.yesterday
    end
  end

  def generate_statistics(start_time)
    puts "Generating udt hourly statistics for #{start_time}"
    statistic_attributes = []
    udt_types = %i[xudt xudt_compatible spore_cell did_cell]
    Udt.where(udt_type: udt_types, published: true).find_each do |udt|
      statistic_attributes << {
        udt_id: udt.id,
        amount: calc_amount(udt),
        ckb_transactions_count: calc_ckb_transactions_count(udt),
        holders_count: calc_holders_count(udt),
        created_at_unixtimestamp: start_time.beginning_of_day.to_i,
      }
    end

    if statistic_attributes.present?
      UdtHourlyStatistic.upsert_all(statistic_attributes, unique_by: %i[udt_id created_at_unixtimestamp])
    end
  end

  def calc_amount(udt)
    inputs_amount = 0
    outputs_amount = 0
    udt.ckb_transactions.includes(:cell_outputs).find_in_batches(batch_size: 1000) do |transactions|
      ids = transactions.map(&:id)
      inputs_amount += CellOutput.select(:udt_amount).where(consumed_by_id: ids).sum(:udt_amount)
      outputs_amount += CellOutput.select(:udt_amount).where(ckb_transaction_id: ids).sum(:udt_amount)
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
