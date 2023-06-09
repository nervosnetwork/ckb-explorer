# Make specific block committed
# this will make the block's transactions committed
# make cell outputs generated to live
# set related statistic info, address info to latest state
class CommitBlockJob < ApplicationJob
  def perform(block)
    case block
    when Integer
      block = Block.find_by id: block
    when String
      block = Block.find_by block_hash: block
    when Block
    else
      raise ArgumentError
    end

    # binding.pry
    block.contained_transactions.each do |tx|
    end

    # reject all the other cell output that is consumed by
    # transactions in current block

    # collect all the previous cell outupts
    # select related cell inputs which are not in current block
    # mark the transaction contains these cell input to be rejected

    # update some statistics and state
  end
end
