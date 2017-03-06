class Metasploit::Goliath::Port < Metasploit::Goliath::Base
  property :port, type: :integer
  belongs_to :address
end