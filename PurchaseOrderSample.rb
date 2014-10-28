require 'base64'
require 'json'
require 'uri'
require 'net/https'

$access_key = "<YOUR PAYMENT ACCESS KEY>"
$secret_key = "<YOUR PAYMENT SECRET KEY>"
$api_endpoint="https://api.btcchina.com/api.php/payment"

def params_string(post_data)
  post_data['params'] = post_data['params'].join(',')
  params_parse(post_data).collect{|k, v| "#{k}=#{v}"} * '&'
end

def params_parse(post_data)
  post_data['accesskey'] = $access_key
  post_data['requestmethod'] = 'post'
  post_data['id'] = post_data['tonce'] unless post_data.keys.include?('id')
  fields=['tonce','accesskey','requestmethod','id','method','params']
  ordered_data = {}
  fields.each do |field|
    ordered_data[field] = post_data[field]
  end
  ordered_data
end

def sign(params_string)
  signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest::Digest.new('sha1'), $secret_key, params_string)
  'Basic ' + Base64.strict_encode64($access_key + ':' + signature)
end

def initial_post_data
  post_data = {}
  post_data['tonce']  = (Time.now.to_f * 1000000).to_i.to_s
  post_data
end

def post_request(post_data)
  uri = URI.parse($api_endpoint)
  payload = params_parse(post_data)
  signature_string = sign(params_string(payload.clone))
  request = Net::HTTP::Post.new(uri.request_uri)
  request.body = payload.to_json
  request.initialize_http_header({"Accept-Encoding" => "identity", 'Json-Rpc-Tonce' => post_data['tonce'], 'Authorization' => signature_string, 'Content-Type' => 'application/json', "User-Agent" => "Kublai"})
  connection(uri, request)
end

def connection(uri, request)
  http = Net::HTTP.new(uri.host, uri.port)
  #http.set_debug_output($stderr)
  if uri.scheme == 'https'
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
  end
  http.read_timeout = 20
  http.open_timeout = 5
  response(http.request(request))
end

def response(response_data)
  if response_data.code == '200' && response_data.body['result']
    JSON.parse(response_data.body)['result']
  elsif response_data.code == '200' && response_data.body['ticker']
    JSON.parse(response_data.body)['ticker']
  elsif response_data.code == '200' && response_data.body['error']
    error = JSON.parse(response_data.body)
    warn("Error Code: #{error['error']['code']}")
    warn("Error Message: #{error['error']['message']}")
    false
  else
    warn("Error Code: #{response_data.code}")
    warn("Error Message: #{response_data.message}")
    warn("check your accesskey/privatekey") if response_data.code == '401'
    false
  end
end

def createPurchaseOrder(price, currency, notificationURL, returnURL=nil, externalKey=nil, itemDesc=nil, phoneNumber=nil, settlementType=0)
  post_data = initial_post_data
  post_data['method']='createPurchaseOrder'
  post_data['params']=[price, currency, notificationURL,returnURL, externalKey, itemDesc, phoneNumber, settlementType]
  post_request(post_data)
end

def getPurchaseOrder(purchaseId)
  post_data = initial_post_data
  post_data['method']='getPurchaseOrder'
  post_data['params']=[purchaseId]
  post_request(post_data)
end

def getPurchaseOrders(limit = 1000, offset=0, fromDate = nil, toDate = nil, status = nil, externalKey = nil )
  post_data = initial_post_data
  post_data['method']='getPurchaseOrders'
  post_data['params']=[limit, offset, fromDate, toDate, status, externalKey]
  post_request(post_data)
end

#debugger

output = createPurchaseOrder(0.5, 'CNY', '<YOUR SERVER URL to PROCESS CALLBACK>', 'http://www.baidu.com', 'demo001', 'A notebook maybe', '13500000001', 0)
#output = createPurchaseOrder(0.0003, 'BTC', 'http://<YOUR SERVER URL to PROCESS CALLBACK>', '<RETURN URL>', 'demo002', 'A notebook maybe', '13500000001', 0)
puts output

#get the purchase order with order_id=1
#po = getPurchaseOrder(1)
#puts po

#get the last 1000 purchase orders
#pos = getPurchaseOrders(1000, 0)
#puts pos
