class SinceParser
  LOCK_TYPE_FLAG = 1 << 63
  METRIC_TYPE_FLAG_MASK = 0x6000_0000_0000_0000
  VALUE_MASK = 0x00ff_ffff_ffff_ffff
  REMAIN_FLAGS_BITS = 0x1f00_0000_0000_0000

  attr_reader :since_int

  def initialize(since)
    @since_int = [since].pack("H*").unpack("Q<").pack("Q>").unpack1("H*").hex
    raise IncorrectSinceFlagsError.new("incorrect since flags") unless flags_is_valid?
  end

  def absolute?
    since_int & LOCK_TYPE_FLAG == 0
  end

  def relative?
    !absolute?
  end

  def flags_is_valid?
    (since_int & REMAIN_FLAGS_BITS == 0) && ((since_int & METRIC_TYPE_FLAG_MASK) != METRIC_TYPE_FLAG_MASK)
  end

  def extract_metric
    value = since_int & VALUE_MASK
    case since_int & METRIC_TYPE_FLAG_MASK
    when 0x0000_0000_0000_0000
      value
    when 0x2000_0000_0000_0000
      CkbUtils.parse_epoch(value)
    when 0x4000_0000_0000_0000
      value * 1000
    end
  end

  alias parse extract_metric

  class IncorrectSinceFlagsError < StandardError; end
end
