require 'msgpack'
require 'httpclient'
require './unity_crypt.rb'
require './request_decoder.rb'
require './conf.rb'

class ApiClient
    include UnityCrypt

    def initialize(udid=nil, user_id=nil, viewer_id=nil)
        if (udid == nil || user_id == nil || viewer_id == nil) then
            if SerializedData::UDID == "" || SerializedData::USER_ID == "" || SerializedData::REQUEST == "" then
                puts "Please configure SerializedData in this script."
                exit(1)
            end

            # Start decoding
            puts "================================================"
            r = RequestDecoder.new
            udid = r.decodeUDID(SerializedData::UDID).to_s
            puts "   UDID: " + udid
            user_id = r.decodeUserID(SerializedData::USER_ID).to_s
            puts "   User ID: " + user_id
            request_body = r.decodeRequestBody(SerializedData::REQUEST, udid)
            viewer_id = r.decodeViewerID(request_body["viewer_id"]).to_s
            puts "   Viewer ID: " + viewer_id
            puts "================================================"
        end
        @udid = udid
        @user_id = user_id
        @viewer_id = viewer_id

        @sid = viewer_id + udid

        @res_ver = ClientData::RES_VER
        @app_ver = ClientData::APP_VER
        @unity_ver = ClientData::UNITY_VER
        @os_ver = ClientData::OS_VER

        @device_id = ClientData::DEVICE_ID
        @device_name = ClientData::DEVICE_NAME
        @user_agent = ClientData::USER_AGENT
        @ip_address = ClientData::IP_ADDRESS
        @gpu_name = ClientData::GPU_NAME
        @keychain = ClientData::KEYCHAIN
        @carrier = ClientData::CARRIER
        @idfa = ClientData::IDFA
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
            'User-Agent' => @user_agent,
            'PARAM' => Digest::SHA1::hexdigest(@udid + @viewer_id + path + plain),
            'USER_ID' => encode(@user_id),
            'PLATFORM_OS_VERSION' => @os_ver,
            'IP_ADDRESS' => @ip_address,
            'DEVICE_ID' => @device_id,
            'KEYCHAIN' => @keychain,
            'GRAPHICS_DEVICE_NAME' => @gpu_name,
            'DEVICE_NAME' => @device_name,
            'UDID' => encode(@udid),
            'SID' => Digest::MD5::hexdigest(@sid + 'r!I@nt8e5i='),
            'Content-Length' => body.bytesize,
            'X-Unity-Version' => @unity_ver,
            'Connection' => 'keep-alive',
            'CARRIER' => @carrier,
            'Accept-Language' => 'en-us',
            'APP_VER' => @app_ver,
            'RES_VER' => @res_ver,
            'Accept' => '*/*',
            'Accept-Encoding' => 'gzip, deflate',
            'Content-Type' => 'application/x-www-form-urlencoded',
            'DEVICE' => '1',
            'IDFA' => @idfa
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
