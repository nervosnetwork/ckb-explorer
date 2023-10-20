require "test_helper"

class PortfolioSignatureVerifierTest < ActiveSupport::TestCase
  setup do
    @sign_info = {
      message: "0x95e919c41e1ae7593730097e9bb1185787b046ae9f47b4a10ff4e22f9c3e3eab",
      signature: "0x1e94db61cff452639cf7dd991cf0c856923dcf74af24b6f575b91479ad2c8ef40769812d1cf1fd1a15d2f6cb9ef3d91260ef27e65e1f9be399887e9a5447786301",
      pub_key: "0x024a501efd328e062c8675f2365970728c859c592beeefd6be8ead3d901330bc01",
      blake160: "0x36c329ed630d6ce750712a477543672adab57f4c"
    }
  end

  test ".recover_from_signature should return encode pub_key" do
    verifier = PortfolioSignatureVerifier.new(nil, @sign_info[:message], @sign_info[:signature], nil)
    pub_key = "0x#{verifier.recover_from_signature}"
    assert_equal pub_key, @sign_info[:pub_key]
  end

  test ".public_key_blake160 should return correct blake160" do
    verifier = PortfolioSignatureVerifier.new(nil, @sign_info[:message], @sign_info[:signature], @sign_info[:pub_key])
    public_key_blake160 = verifier.public_key_blake160
    assert_equal public_key_blake160, @sign_info[:blake160]
  end

  test ".verified? should return true with correct signature" do
    ENV["CKB_NET_MODE"] = "testnet"
    address = "ckt1qzda0cr08m85hc8jlnfp3zer7xulejywt49kt2rr0vthywaa50xwsqfkcv576ccddnn4quf2ga65xee2m26h7nq4sds0r"
    verifier = PortfolioSignatureVerifier.new(address, @sign_info[:message], @sign_info[:signature], nil)
    assert_equal true, verifier.verified?

    ENV["CKB_NET_MODE"] = "mainnet"
  end
end
