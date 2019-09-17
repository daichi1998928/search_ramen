class LinebotController < ApplicationController
    require 'line/bot'  # gem 'line-bot-api'

  # callbackアクションのCSRFトークン認証を無効
    protect_from_forgery :except => [:callback]

    def client
        @client ||= Line::Bot::Client.new { |config|
        config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
        config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
        }
    end

    def callback
        body = request.body.read

        signature = request.env['HTTP_X_LINE_SIGNATURE']
        unless client.validate_signature(body, signature)
        head :bad_request
        end

        events = client.parse_events_from(body)

        events.each { |event|

        if event.message['text'] != nil
            address = event.message['text']
            key_id = ENV['ACCESS_KEY']
            #URLの文字列をURIオブジェクトへと生成いたします
            area_result = URI.parse("https://api.gnavi.co.jp/RestSearchAPI/v3/?keyid=#{key_id}&address=#{URI.encode(address)}&freeword=#{URI.encode('ラーメン')}")
            #上の処理で返ってきたURIオブジェクトを元にAPIを叩いてくれる
            json_result = Net::HTTP.get(area_result)
            #レスポンスが文字列形式のJSONで返ってくる。下記の処理でハッシュオブジェクトに変換している
            hash_result = JSON.parse json_result
        end



        case event
        when Line::Bot::Event::Message
            case event.type
            when Line::Bot::Event::MessageType::Text
            message = {
                type: 'text',
                text: event.message['text']
            }
            client.reply_message(event['replyToken'], message)
            end
        end
        }

        head :ok
    end






end
