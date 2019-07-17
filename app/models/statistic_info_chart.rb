class StatisticInfoChart
  def initialize
    @max_block_number = Block.maximum(:number)
    @last_epoch0_block_number = Block.available.where(epoch: 0).recent.first.number
  end

  def id
    Time.current.to_i
  end

  def hash_rate
    result =
      (@last_epoch0_block_number + 1).step(@max_block_number, 100).map do |number|
        blocks = Block.where("number <= ?", number).available.recent.includes(:uncle_blocks).limit(100)
        next if blocks.blank?

        total_difficulties = blocks.flat_map { |block| [block, *block.uncle_blocks] }.reduce(0) { |sum, block| sum + block.difficulty.hex }
        total_time = blocks.first.timestamp - blocks.last.timestamp
        hash_rate = total_difficulties.to_d / total_time / cycle_rate
        { block_number: number, hash_rate: hash_rate }
      end

    result.compact
  end

  def difficulty
    block_numbers = (@last_epoch0_block_number + 1).step(@max_block_number, 100).to_a
    Block.where(number: block_numbers).available.order(:number).select(:number, :difficulty).map do |block|
      { block_number: block.number, difficulty: block.difficulty.hex }
    end
  end

  private

  def n_l(n, l)
    ((n - l + 1)..n).reduce(1, :*)
  end

  # this formula comes from https://www.youtube.com/watch?v=CLiKX0nOsHE&feature=youtu.be&list=PLvgCPbagiHgqYdVUj-ylqhsXOifWrExiq&t=1242
  # n and l is Cuckoo's params
  # on ckb testnet the value of 'n' is 2**15 and the value of 'l' is 12
  # the value of n and l and this formula are unstable, will change as the POW changes.
  def cycle_rate
    n = 2**15
    l = 12
    n_l(n, l).to_f / (n**l) * (n_l(n, l / 2)**2) / (n**l) / l
  end
end
