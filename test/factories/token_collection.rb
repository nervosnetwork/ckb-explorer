FactoryBot.define do
  factory :token_collection do
    standard { "m_nft" }
    name {"mNft-name"}
    description {"i am a nft collection "}
    icon_url {"https://icon.a.com/1.mp4"}
    items_count {3}
    holders_count {2}
    symbol {"MMN"}
    verified { false}
    sn {"0x66a89c702ffed8234a772f96dcd431cf48e5297736ad5caeff723251c96c265c"}

  end
end
