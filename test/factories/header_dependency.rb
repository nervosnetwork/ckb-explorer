FactoryBot.define do
  factory :header_dependency do
    before(:create) do |h, _eval|
      create :block, block_hash: h.header_hash unless Block.where(block_hash: h.header_hash).exists?
    end
  end
end
