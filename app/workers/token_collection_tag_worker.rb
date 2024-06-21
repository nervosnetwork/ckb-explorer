class TokenCollectionTagWorker
  include Sidekiq::Job

  def perform
    token_collections = TokenCollection.preload(:creator).where(tags: []).where.not("name IS NULL OR name = ''").limit(100)
    unless token_collections.empty?
      attrs =
        token_collections.map do |token_collection|
          tags = mark_tags(token_collection)
          { id: token_collection.id, tags: }
        end

      TokenCollection.upsert_all(attrs, unique_by: :id, on_duplicate: :update, update_only: :tags)
    end
  end

  def mark_tags(token_collection)
    if invalid_char?(token_collection.name)
      ["invalid"]
    elsif invisible_char?(token_collection.name)
      ["suspicious"]
    elsif out_of_length?(token_collection.name)
      ["out-of-length-range"]
    elsif first_token_collection?(token_collection.name, token_collection.block_timestamp, token_collection.standard)
      if rgbpp_lock?(token_collection.creator.address_hash)
        ["rgbpp-compatible", "layer-1-asset"]
      else
        ["rgbpp-compatible", "layer-2-asset"]
      end
    elsif rgbpp_lock?(token_collection.creator.address_hash)
      ["duplicate", "layer-1-asset"]
    else
      ["duplicate", "layer-2-asset"]
    end
  end

  def invalid_char?(name)
    !name.ascii_only?
  end

  def invisible_char?(name)
    (name =~ /^[\x21-\x7E]+$/).nil?
  end

  def out_of_length?(name)
    name.length > 255
  end

  def first_token_collection?(name, block_timestamp, standard)
    !TokenCollection.where(name:, standard:).where("block_timestamp < ?", block_timestamp).exists?
  end

  def rgbpp_lock?(issuer_address)
    address_code_hash = CkbUtils.parse_address(issuer_address).script.code_hash
    issuer_address.present? && CkbSync::Api.instance.rgbpp_code_hash.include?(address_code_hash)
  end
end
