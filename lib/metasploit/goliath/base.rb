class Metasploit::Goliath::Base < JsonApiClient::Resource
  self.site = 'http://localhost:3000'
  self.json_key_format = :dasherized_key
end
