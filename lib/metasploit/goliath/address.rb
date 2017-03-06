class Metasploit::Goliath::Address < Metasploit::Goliath::Base
  property :ip, type: :inet
  has_many :ports
end