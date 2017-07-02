require 'crypt/rijndael'
require 'base64'
require 'active_support/core_ext/kernel'

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
        Kernel::silence_warnings do
            r = Crypt::Rijndael.new(key, key.length * 8, iv.length * 8)
            s += "\0" * (iv.length - s.length % iv.length) if s.length % iv.length > 0
            blocks = s.each_char.each_slice(iv.length).map(&:join)
            out = [iv]
            blocks.each{|b| out << r.encrypt_block(b ^ out.last)}
            out[1..-1].join
        end
    end

    def decrypt_rj256(s, key, iv)
        Kernel::silence_warnings do
            r = Crypt::Rijndael.new(key, key.length * 8, iv.length * 8)
            blocks = s.each_char.each_slice(iv.length).map(&:join)
            decrypted = blocks.map{|b| r.decrypt_block(b)}.join
            ((iv + s)[0, decrypted.length] ^ decrypted).split("\0").first
        end
    end
end
