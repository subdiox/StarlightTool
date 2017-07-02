require './api_client.rb'

client = ApiClient.new()
p client.call('/load/check', {})
