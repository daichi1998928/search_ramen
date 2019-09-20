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
        else
            latitude = event.message['latitude']
            longitude = event.message['longitude']
    
            key_id = ENV['ACCESS_KEY']
            area_result = URI.parse("https://api.gnavi.co.jp/RestSearchAPI/v3/?keyid=#{key_id}&latitude=#{latitude}&longitude=#{longitude}&freeword=#{URI.encode('ラーメン')}")
            json_result = Net::HTTP.get(area_result)
            hash_result = JSON.parse json_result
        end

        if hash_result.has_key?("error")
          response = "送信していただいたエリアの付近でラーメン店をぐるなびから探すことはできませんでした。申し訳ございませんが他のツールをお使いください"
          case event
          when Line::Bot::Event::Message
            case event.type
            when Line::Bot::Event::MessageType::Text,Line::Bot::Event::MessageType::Location
              message = {
              type: 'text',
              text: response
            }
               client.reply_message(event['replyToken'], [message])
            end
          end
        end

        if ramen_shop_info = hash_result["rest"]
           ramen_shops_shuffle = ramen_shop_info.shuffle
           ramen_shop = ramen_shops_shuffle.sample
           flex_response = reply(ramen_shop)
           map_response = shop_address(ramen_shop)
        end
        case event
        when Line::Bot::Event::Message
            case event.type
            when Line::Bot::Event::MessageType::Text,Line::Bot::Event::MessageType::Location
            
            client.reply_message(event['replyToken'], [flex_response,map_response])
            end
        end
        }
         head :ok
    end


    def  reply(ramen_shop)
        ramen_url = ramen_shop["url_mobile"]
        ramen_name = ramen_shop["name"]
        if  ramen_shop["image_url"]["shop_image1"].present?
            ramen_image = ramen_shop["image_url"]["shop_image1"]
        else
            ramen_image = "https://image.shutterstock.com/image-photo/japanese-ramen-soup-chicken-egg-260nw-377093743.jpg"
        end
        
        open_time = ramen_shop["opentime"]
        holiday = ramen_shop["holiday"]
        ramen_budget = ramen_shop["budget"].to_s

        if open_time.class != String 
            open_time = ""
        end
        if holiday.class != String
            holiday = ""
        end

        {
            "type": "flex",
            "altText": "this is a flex message",
            "contents": {
              "type": "bubble",
              "hero": {
                "type": "image",
                "url": ramen_image,
                "size": "full",
                "aspectRatio": "20:13",
                "aspectMode": "cover",
              },
              "body": {
                "type": "box",
                "layout": "vertical",
                "contents": [
                  {
                    "type": "text",
                    "text": ramen_name,
                    "weight": "bold",
                    "size": "lg"
                  },
                  {
                    "type": "box",
                    "layout": "vertical",
                    "margin": "lg",
                    "spacing": "md",
                    "contents": [
                      {
                        "type": "box",
                        "layout": "baseline",
                        "spacing": "md",
                        "contents": [
                          {
                            "type": "text",
                            "text": "予算",
                            "color": "#aaaaaa",
                            "size": "md",
                            "flex": 3
                          },
                          {
                            "type": "text",
                            "text": ramen_budget,
                            "wrap": true,
                            "color": "#666666",
                            "size": "lg",
                            "flex": 5
                          }
                        ]
                      },
                      {
                        "type": "box",
                        "layout": "baseline",
                        "spacing": "md",
                        "contents": [
                          {
                            "type": "text",
                            "text": "定休日",
                            "color": "#aaaaaa",
                            "size": "md",
                            "flex": 3
                          },
                          {
                            "type": "text",
                            "text": holiday,
                            "wrap": true,
                            "color": "#666666",
                            "size": "md",
                            "flex": 5
                          }
                        ]
                      },
                      {
                        "type": "box",
                        "layout": "baseline",
                        "spacing": "md",
                        "contents": [
                          {
                            "type": "text",
                            "text": "開店時間",
                            "color": "#aaaaaa",
                            "size": "md",
                            "flex": 3
                          },
                          {
                            "type": "text",
                            "text": open_time,
                            "wrap": true,
                            "color": "#666666",
                            "size": "md",
                            "flex": 5
                          }
                        ]
                      }
                    ]
                  }
                ]
              },
              "footer": {
                "type": "box",
                "layout": "vertical",
                "spacing": "sm",
                "contents": [
                  {
                    "type": "button",
                    "style": "link",
                    "height": "sm",
                    "action": {
                      "type": "uri",
                      "label": "もっと詳しく！",
                      "uri": ramen_url
                    }
                  },
                  {
                    "type": "spacer",
                    "size": "sm"
                  }
                ],
                "flex": 0
              }
            }
          }
    end

    def shop_address(ramen_shop)
      shop_name = ramen_shop["name"]
      address = ramen_shop["address"]
      latitude = ramen_shop["latitude"]
      longitude = ramen_shop["longitude"]
      {
        "type": "location",
        "title": shop_name,
        "address": address ,
        "latitude": latitude,
        "longitude": longitude
      }
     end


end
