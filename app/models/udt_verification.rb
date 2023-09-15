class UdtVerification < ApplicationRecord
  SENT_FREQUENCY_MINUTES = 1
  KEEP_ALIVE_MINUTES = 10

  class TokenExpiredError < StandardError; end
  class TokenNotMatchError < StandardError; end
  class TokenSentTooFrequentlyError < StandardError; end

  belongs_to :udt

  def refresh_token!(ip)
    raise TokenSentTooFrequentlyError if sent_at.present? && self.sent_at + SENT_FREQUENCY_MINUTES.minutes > Time.now

    self.token = rand(999999).to_s.rjust(6, "0")
    self.sent_at = Time.now
    self.last_ip = ip
    self.save!
  end

  def validate_token!(token_params)
    raise TokenExpiredError if self.sent_at + KEEP_ALIVE_MINUTES.minutes < Time.now
    raise TokenNotMatchError if token != token_params.to_i
  end
end

# == Schema Information
#
# Table name: udt_verifications
#
#  id            :bigint           not null, primary key
#  token         :integer
#  sent_at       :datetime
#  last_ip       :inet
#  udt_id        :bigint
#  udt_type_hash :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_udt_verifications_on_udt_id         (udt_id)
#  index_udt_verifications_on_udt_type_hash  (udt_type_hash) UNIQUE
#
