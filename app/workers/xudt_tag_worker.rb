class XudtTagWorker
  include Sidekiq::Job

  def perform
    udts = Udt.published_xudt.left_joins(:xudt_tag).where(xudt_tag: { id: nil }).limit(100)
    if !udts.empty?
      attrs =
        udts.map do |udt|
          tags = mark_tags(udt)
          { udt_id: udt.id, udt_type_hash: udt.type_hash, tags: }
        end

      XudtTag.upsert_all(attrs, unique_by: :udt_id, on_duplicate: :update, update_only: :tags)
    end
  end

  def mark_tags(udt)
    if udt.symbol.blank?
      ["unnamed"]
    elsif invalid_char?(udt.symbol)
      ["invalid"]
    elsif invisible_char?(udt.symbol)
      ["suspicious"]
    elsif out_of_length?(udt.symbol)
      ["out-of-length-range"]
    elsif first_xudt?(udt.symbol, udt.block_timestamp)
      if rgbpp_lock?(udt.issuer_address)
        ["rgbpp-compatible", "layer-1-asset", "supply-limited"]
      else
        ["rgbpp-compatible", "layer-2-asset", "supply-unlimited"]
      end
    elsif rgbpp_lock?(udt.issuer_address)
      ["duplicate", "layer-1-asset", "supply-limited"]
    else
      ["duplicate", "layer-2-asset", "supply-unlimited"]
    end
  end

  def invalid_char?(symbol)
    !symbol.ascii_only?
  end

  def invisible_char?(symbol)
    (symbol =~ /^[\x21-\x7E]+$/).nil?
  end

  def out_of_length?(symbol)
    symbol.length > 5 || symbol.length < 4
  end

  def first_xudt?(symbol, block_timestamp)
    !Udt.published_xudt.where("LOWER(symbol) = ?", symbol.downcase).where("block_timestamp < ?", block_timestamp).exists?
  end

  def rgbpp_lock?(issuer_address)
    issuer_address.present? && CkbUtils.parse_address(issuer_address).script.code_hash == Settings.rgbpp_code_hash
  end

  ## TODO: current no this condition
  def omni_lock_with_supply_mode?(issuer_address); end
end
