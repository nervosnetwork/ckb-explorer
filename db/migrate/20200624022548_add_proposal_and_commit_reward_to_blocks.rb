class AddProposalAndCommitRewardToBlocks < ActiveRecord::Migration[6.0]
  def change
    add_column :blocks, :proposal_reward, :decimal, precision: 30
    add_column :blocks, :commit_reward, :decimal, precision: 30
    add_column :forked_blocks, :proposal_reward, :decimal, precision: 30
    add_column :forked_blocks, :commit_reward, :decimal, precision: 30
  end
end
