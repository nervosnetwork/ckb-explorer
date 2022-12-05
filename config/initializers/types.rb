class CkbHashType < ActiveRecord::Type::Binary
  def deserialize(value)
    return if value.nil?

    if value.is_a?(String)
      value = ActiveRecord::Base.connection.unescape_bytea(value)
    end
    "#{Settings.default_hash_prefix}#{value.to_s.unpack1('H*')}"
  end

  def serialize(value)
    return if value.nil?

    if value.is_a?(String) && value.start_with?("0x")
      value = [value.delete_prefix(Settings.default_hash_prefix)].pack("H*")
      ActiveRecord::Base.connection.escape_bytea(value)
    else
      super
    end
  end
end

class CkbArrayHashType < ActiveRecord::Type::Binary
  def initialize(hash_length:)
    @hash_length = hash_length
  end

  def deserialize(value)
    return if value.nil?

    if value.is_a?(String)
      value = ActiveRecord::Base.connection.unescape_bytea(value)
    end

    array_size = value.unpack1("S!")
    template = Array.new(array_size || 0).reduce("") { |memo, _item| "#{memo}H#{@hash_length}" }
    template = "S!#{template}"
    value.unpack(template.to_s).drop(1).map { |hash| "#{Settings.default_hash_prefix}#{hash}" }.reject(&:blank?)
  end

  def serialize(value)
    return if value.nil?
    return if value.is_a?(Array) && value.all?(&:nil?)

    if value.is_a?(Array) && value.all? { |item| item.start_with?("0x") }
      template = Array.new(value.size).reduce("") { |memo, _item| "#{memo}H#{Settings.default_hash_length}" }
      real_value = value.map { |hash| hash.delete_prefix(Settings.default_hash_prefix) }
      real_value.unshift(real_value.size)
      template = "S!#{template}"
      value = real_value.pack(template)
      ActiveRecord::Base.connection.escape_bytea(value)
    else
      super
    end
  end
end

ActiveRecord::Type.register(:ckb_hash, CkbHashType)
ActiveRecord::Type.register(:ckb_array_hash, CkbArrayHashType)
