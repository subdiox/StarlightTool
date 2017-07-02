require './unity_crypt.rb'

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
