class DistributionData
  VALID_INDICATORS = %w(address_balance_distribution block_time_distribution epoch_time_distribution epoch_length_distribution average_block_time nodes_distribution block_propagation_delay_history transaction_propagation_delay_history).freeze

  def id
    Time.current.to_i
  end

  def address_balance_distribution
    DailyStatistic.order(created_at_unixtimestamp: :desc).first&.address_balance_distribution || []
  end

  def block_time_distribution
    DailyStatistic.order(created_at_unixtimestamp: :desc).first&.block_time_distribution || []
  end

  def epoch_time_distribution
    DailyStatistic.order(created_at_unixtimestamp: :desc).first&.epoch_time_distribution || []
  end

  def epoch_length_distribution
    DailyStatistic.order(created_at_unixtimestamp: :desc).first&.epoch_length_distribution || []
  end

  def average_block_time
    DailyStatistic.order(created_at_unixtimestamp: :desc).first&.average_block_time || []
  end

  def nodes_distribution
    DailyStatistic.order(created_at_unixtimestamp: :desc).first&.nodes_distribution || DailyStatistic.where.not(nodes_distribution: nil).order(created_at_unixtimestamp: :desc).first&.nodes_distribution || []
  end

  def block_propagation_delay_history
    round_num = 4
    sql =
      <<-SQL
        select created_at_unixtimestamp,
          round(avg((durations->>0)::numeric), #{round_num}) avg5, round(avg((durations->>1)::numeric), #{round_num}) avg10,
          round(avg((durations->>2)::numeric), #{round_num}) avg15, round(avg((durations->>3)::numeric), #{round_num}) avg20,
          round(avg((durations->>4)::numeric), #{round_num}) avg25, round(avg((durations->>5)::numeric), #{round_num}) avg30,
          round(avg((durations->>6)::numeric), #{round_num}) avg35, round(avg((durations->>7)::numeric), #{round_num}) avg40,
          round(avg((durations->>8)::numeric), #{round_num}) avg45, round(avg((durations->>9)::numeric), #{round_num}) avg50,
          round(avg((durations->>10)::numeric), #{round_num}) avg55, round(avg((durations->>11)::numeric), #{round_num}) avg60,
          round(avg((durations->>12)::numeric), #{round_num}) avg65, round(avg((durations->>13)::numeric), #{round_num}) avg70,
          round(avg((durations->>14)::numeric), #{round_num}) avg75, round(avg((durations->>15)::numeric), #{round_num}) avg80,
          round(avg((durations->>16)::numeric), #{round_num}) avg85, round(avg((durations->>17)::numeric), #{round_num}) avg90
        from block_propagation_delays
        group by created_at_unixtimestamp
        order by created_at_unixtimestamp
      SQL

    BlockPropagationDelay.connection.select_all(sql)
  end

  def transaction_propagation_delay_history
    round_num = 4
    sql =
      <<-SQL
        select created_at_unixtimestamp,
          round(avg((durations->>0)::numeric), #{round_num}) avg5, round(avg((durations->>1)::numeric), #{round_num}) avg10,
          round(avg((durations->>2)::numeric), #{round_num}) avg15, round(avg((durations->>3)::numeric), #{round_num}) avg20,
          round(avg((durations->>4)::numeric), #{round_num}) avg25, round(avg((durations->>5)::numeric), #{round_num}) avg30,
          round(avg((durations->>6)::numeric), #{round_num}) avg35, round(avg((durations->>7)::numeric), #{round_num}) avg40,
          round(avg((durations->>8)::numeric), #{round_num}) avg45, round(avg((durations->>9)::numeric), #{round_num}) avg50,
          round(avg((durations->>10)::numeric), #{round_num}) avg55, round(avg((durations->>11)::numeric), #{round_num}) avg60,
          round(avg((durations->>12)::numeric), #{round_num}) avg65, round(avg((durations->>13)::numeric), #{round_num}) avg70,
          round(avg((durations->>14)::numeric), #{round_num}) avg75, round(avg((durations->>15)::numeric), #{round_num}) avg80,
          round(avg((durations->>16)::numeric), #{round_num}) avg85, round(avg((durations->>17)::numeric), #{round_num}) avg90
        from transaction_propagation_delays
        group by created_at_unixtimestamp
        order by created_at_unixtimestamp
      SQL

    TransactionPropagationDelay.connection.select_all(sql)
  end
end
