require 'crypt/rijndael'
require 'msgpack'
require 'base64'
require 'httpclient'

# Use mitmproxy or something to obtain the following data (Base64 Encoded)
module SerializedData
    UDID = ""
    USER_ID = ""
    REQUEST = ""
end

module UnityCrypt
    def b64e(s)
        Base64::strict_encode64(s)
    end

    def b64d(s)
        Base64::strict_decode64(s)
    end

    def encode(s)
        '%04x' % s.length +
            s.chars.map{|c| '%02d' % rand(100) + (c.ord + 10).chr + rand(10).to_s}.join +
            (0...32).map{rand(10)}.join
    end

    def decode(s)
        return s if s.length < 4
        (0...s[0, 4].to_i(16)).map{|i| (s[i * 4 + 6].ord - 10).chr}.join
    end

    def encrypt_rj256(s, key, iv)
        r = Crypt::Rijndael.new(key, key.length * 8, iv.length * 8)
        s += "\0" * (iv.length - s.length % iv.length) if s.length % iv.length > 0
        blocks = s.each_char.each_slice(iv.length).map(&:join)
        out = [iv]
        blocks.each{|b| out << r.encrypt_block(b ^ out.last)}
        out[1..-1].join
    end

    def decrypt_rj256(s, key, iv)
        r = Crypt::Rijndael.new(key, key.length * 8, iv.length * 8)
        blocks = s.each_char.each_slice(iv.length).map(&:join)
        decrypted = blocks.map{|b| r.decrypt_block(b)}.join
        ((iv + s)[0, decrypted.length] ^ decrypted).split("\0").first
    end
end

class ApiClient
    include UnityCrypt

    def initialize(udid, user_id, viewer_id)
        @udid = udid
        @user_id = user_id
        @viewer_id = viewer_id
        @sid = viewer_id + udid
        @res_ver = '10028100'
        @app_ver = '3.0.4'
    end

    def call(path, args)
        args['timezone'] = '09:00:00'
        vid_iv = (0...32).map{rand(10)}.join
        args['viewer_id'] = vid_iv + Base64::strict_encode64(encrypt_rj256(@viewer_id, "s%5VNQ(H$&Bqb6#3+78h29!Ft4wSg)ex", vid_iv))
        msgpack = MessagePack::Packer.new({:compatibility_mode => true}).write(args).flush
        plain = b64e(msgpack.to_s)
        key = b64e((0...32).map{'%x' % rand(65536)}.join)[0...32]
        msg_iv = @udid.gsub('-', '')
        body = b64e(encrypt_rj256(plain, key, msg_iv) + key)
        header = {
            'Host' => 'game.starlight-stage.jp',
            'User-Agent' => 'BNEI0242/96 CFNetwork/808.2.16 Darwin/16.3.01',
            'Content-Type' => 'application/x-www-form-urlencoded',
            'Content-Length' => body.bytesize,
            'Connection' => 'keep-alive',
            'Accept' => '*/*',
            'Accept-Encoding' => 'gzip, deflate',
            'Accept-Language' => 'en-us',
            'X-Unity-Version' => '5.4.5p1',
            'UDID' => encode(@udid),
            'USER_ID' => encode(@user_id),
            'SID' => Digest::MD5::hexdigest(@sid + 'r!I@nt8e5i='),
            'PARAM' => Digest::SHA1::hexdigest(@udid + @viewer_id + path + plain),
            'DEVICE' => '1',
            'APP_VER' => @app_ver,
            'RES_VER' => @res_ver,
            'DEVICE_ID' => '10FB122A-CC47-4B10-8C78-0D1E6C22119C',
            'DEVICE_NAME' => 'iPhone8,1',
            'GRAPHICS_DEVICE_NAME' => 'Apple A9 GPU',
            'IP_ADDRESS' => '192.168.12.14',
            'PLATFORM_OS_VERSION' => 'iPhone OS 10.2',
            'CARRIER' => '',
            'KEYCHAIN' => '339871861'
        }

        client = HTTPClient.new
        response = client.post_content('http://game.starlight-stage.jp' + path, body, header)
        res_body = b64d(response)
        res_plain = decrypt_rj256(res_body[0...-32], res_body[-32, 32], msg_iv)
        pack = MessagePack::unpack(b64d(res_plain))
        @sid = pack['data_headers']['sid']
        pack
    end
end

class RequestDecoder
    include UnityCrypt

    def decodeUDID(encoded_string)
        return decode(encoded_string).downcase
    end

    def decodeUserID(encoded_string)
        return decode(encoded_string)
    end

    def decodeRequestBody(encoded_string, decoded_UDID)
        raw_string = b64d(encoded_string)
        msg_iv = decoded_UDID.downcase.gsub('-', '')
        body_plain = decrypt_rj256(raw_string[0...-32], raw_string[-32, 32], msg_iv)
        return MessagePack::unpack(b64d(body_plain))
    end

    def decodeViewerID(encoded_string)
        raw_string = b64d(encoded_string[32..-1])
        vid_iv = encoded_string[0...32]
        body_plain = decrypt_rj256(raw_string, "s%5VNQ(H$&Bqb6#3+78h29!Ft4wSg)ex", vid_iv)
        return body_plain
    end
end

if SerializedData::UDID == "" || SerializedData::USER_ID == "" || SerializedData::REQUEST == "" then
    puts "Please configure SerializedData in this script."
    exit(1)
end

# Start decoding
r = RequestDecoder.new
udid = r.decodeUDID(SerializedData::UDID)
puts "UDID: " + udid
user_id = r.decodeUserID(SerializedData::USER_ID)
puts "User ID: " + user_id
request_body = r.decodeRequestBody(SerializedData::REQUEST, udid)
viewer_id = r.decodeViewerID(request_body["viewer_id"])
puts "Viewer ID: " + viewer_id

client = ApiClient.new(udid, user_id, viewer_id)

p client.call('/load/check', {})
