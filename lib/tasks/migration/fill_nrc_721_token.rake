namespace :migration do
  desc "Usage: RAILS_ENV=production bundle exec rake migration:fill_nrc_721_token"
  task fill_nrc_721_token: :environment do
    outputs = CellOutput.where(tx_hash: "0x09d9bbd0d3745fad1334b9294456a1a70e66730195f46ab3c5ab120dd8ff3dc2")
    nrc_721_tokens = outputs[0..4]
    nrc_721_factory = outputs[5]
    nrc_721_tokens.each { |token| token.update(cell_type: "nrc_721_token")) }

    puts "done"
  end
end
