require "ecdsa"

class PortfolioSignatureVerifier
  attr_reader :address, :message, :signature, :pub_key

  def initialize(address, message, signature, pub_key)
    @address = address
    @message = message
    @signature = signature
    @pub_key = pub_key
  end

  def verified?
    @pub_key ||= recover_from_signature
    puts "pub_key: #{@pub_key}"

    encode_address = blake160_address
    puts "encode_address: #{encode_address}"
    address == encode_address
  end

  def blake160_address
    CkbUtils.generate_address(default_lock_script)
  end

  def recover_from_signature
    group = ECDSA::Group::Secp256k1
    msg_buffer = [message[2..]].pack("H*")
    sig_buffer = [signature[2..]].pack("H*")

    sign = ECDSA::Signature.new(
      sig_buffer.slice(0..31).unpack1("H*").to_i(16),
      sig_buffer.slice(32..63).unpack1("H*").to_i(16)
    )

    points = ECDSA.recover_public_key(group, msg_buffer, sign)
    ECDSA::Format::PointOctetString.encode(points.first, compression: true).unpack1("H*")
  end

  def default_lock_script
    puts "blake160: #{public_key_blake160}"
    CKB::Types::Script.generate_lock(public_key_blake160, CKB::SystemCodeHash::SECP256K1_BLAKE160_SIGHASH_ALL_TYPE_HASH)
  end

  def public_key_blake160
    CKB::Key.blake160(pub_key)
  end
end
