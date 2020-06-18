namespace :migration do
  task fill_issuer_address_to_udts: :environment do
    values = Udt.where(issuer_address: nil, published: true).map do |udt|
      { id: udt.id, issuer_address: Address.where(lock_hash: udt.args).select(:address_hash).first.address_hash, created_at: udt.created_at, updated_at: udt.updated_at }
    end

    Udt.upsert_all(values) if values.present?

    puts "done"
  end
end
