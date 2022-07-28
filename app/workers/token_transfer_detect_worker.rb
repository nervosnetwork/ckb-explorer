class TokenTransferDetectWorker 
  include Sidekiq::Worker

  def perform(tx_id)
    tx = CkbTransaction.find tx_id
    return unless tx
    source_nfts = []
    tx.cell_inputs.each do |input|
      if input.cell_type.in?(%w(m_nft_token nrc_721_token))
        
      end
    end

    tx.cell_outputs.each do |output|
      if output.cell_type.in?(%w(m_nft_token nrc_721_token))

      end
    end
  end
end
