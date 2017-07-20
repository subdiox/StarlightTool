require "uri"
require "net/http"
require "json"
require "inline"
require "lz4"

#-------------- Configs --------------#
# Platform (iOS or Android)
Platform = "iOS"
# Quality (High or Low)
AssetBundles_Quality = "High"
Sound_Quality = "High"
# X-Unity-Version
Unity_Version = "5.1.2f1"
#-------------------------------------#

# Config Check
config_okay = true
if Platform != "iOS" && Platform != "Android"
    config_okay = false
end
if AssetBundles_Quality != "High" && AssetBundles_Quality != "Low"
    config_okay = false
end
if Sound_Quality != "High" && Sound_Quality != "Low"
    config_okay = false
end
if !config_okay
    puts "Configs are not set correctly. Please check them again."
    exit
end

# Set End Points of Tachibana API
class Tachibana
    def api_url
        "https://api.tachibana.cool/v1"
    end
    def latest_json
        "/starlight/meta/latest.json"
    end
end

# Get Latest Version Info
tachibana = Tachibana.new
version_info = JSON.parse(Net::HTTP.get(URI.parse(tachibana.api_url + tachibana.latest_json)))
APP_VER = version_info["APP_VER"]["value"]
RES_VER = version_info["RES_VER"]["value"]

# Output
puts "----------------------"
puts "  APP_VER : " + APP_VER
puts "  RES_VER : " + RES_VER
puts "----------------------"

# Set End Points of Starlight API
class Starlight
    def api_url
        "storages.game.starlight-stage.jp"
    end
    def header
        {"X-Unity-Version" => Unity_Version}
    end
    def manifests
        "/dl/#{RES_VER}/manifests/#{Platform}_A#{AssetBundles_Quality}_S#{Sound_Quality}"
    end
    def asset_bundles_resource
        "/dl/resources/#{AssetBundles_Quality}/AssetBundles/#{Platform}"
    end
    def sound_resource
        "/dl/resources/#{Sound_Quality}/Sound/Common/"
    end
end

starlight = Starlight.new
Net::HTTP.start(starlight.api_url) do |http|
    res = http.get(starlight.manifests, starlight.header)
    open('manifests.sqlite.lz4', 'wb'){|f|
        f.write(res.body)
    }
    lz4 = LZ4.new()
    manifests_sqlite = lz4.startDecompress("manifests.sqlite.lz4")
end


=begin
 RES_VER=`curl -s https://api.tachibana.cool/v1/starlight/meta/latest.json | jq -r ".RES_VER.value"`
2. curl -s -H "X-Unity-Version: 5.1.2f1" https://storages.game.starlight-stage.jp/dl/$RES_VER/manifests/iOS_AHigh_SHigh -o iOS_AHigh_SHigh.sqlite.lz4
3.
=end
