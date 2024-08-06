class XudtTagWorker
  include Sidekiq::Job

  def perform
    udts = Udt.published_xudt.left_joins(:xudt_tag).where(xudt_tag: { id: nil }).limit(100)
    if !udts.empty?
      attrs =
        udts.map do |udt|
          tags = mark_tags(udt)
          tags << "rgb++" if udt.xudt? && !tags.include?("rgb++")
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
    elsif utility_lp_token?(udt.args)
      ["utility"]
    elsif !first_xudt?(udt.symbol, udt.block_timestamp)
      ["suspicious"]
    elsif single_use_lock?(udt.issuer_address)
      ["supply-limited"]
    elsif rgbpp_lock?(udt.issuer_address)
      ["rgb++", "layer-1-asset", "supply-limited"]
    else
      ["rgb++", "layer-2-asset", "supply-unlimited"]
    end
  end

  def invalid_char?(symbol)
    !symbol.ascii_only?
  end

  def invisible_char?(symbol)
    (symbol =~ /^[\x21-\x7E]+(?:\s[\x21-\x7E]+)?$/).nil?
  end

  def out_of_length?(symbol)
    symbol.length > 5 || symbol.length < 4
  end

  def first_xudt?(symbol, block_timestamp)
    !Udt.published_xudt.where("LOWER(symbol) = ?", symbol.downcase).where("block_timestamp < ?", block_timestamp).exists?
  end

  def rgbpp_lock?(issuer_address)
    address_code_hash = CkbUtils.parse_address(issuer_address).script.code_hash
    issuer_address.present? && CkbSync::Api.instance.rgbpp_code_hash.include?(address_code_hash)
  end

  def single_use_lock?(issuer_address)
    address_script = CkbUtils.parse_address(issuer_address).script
    issuer_address.present? && CkbSync::Api.instance.single_use_lock_code_hash == address_script.code_hash && address_script.hash_type == "data1"
  end

  def utility_lp_token?(args)
    args.length == 74
  end

  ## TODO: current no this condition
  def omni_lock_with_supply_mode?(issuer_address); end
end
