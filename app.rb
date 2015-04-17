require "sinatra"
require "twilio-ruby"
require "chucknorris"
require "redis"

post '/message' do

  twiml = Twilio::TwiML::Response.new do |r|
    case params[:Body].downcase
      when /^start/
        r.message start params[:From]
      when /^join/
        r.message join params[:From], params[:Body]
      when /^beer/
        r.message beer params[:From]
      when /^leave/
        r.message leave params[:From]
      else
        r.message "Talk sense fool"
    end
  end

  twiml.text
end

post '/twiml' do
  content_type 'text/xml'
  '<Response>
      <Say voice="alice" language="en-CA">' + ChuckNorris.random + '. Time to get the drinks in!</Say>
  </Response>'
end

def start(from)
  redis = Redis.new
  code = rand(1000...9999).to_s
  redis.rpush("barchuck_game_" + code, from)
  assign_player_code from, code
  "Players text JOIN " + code
end

def join(from, body)
  redis = Redis.new
  match = body.match(/join (\d\d\d\d)/im)
  if match == nil
    "Could not join, you need a 4 digit code dawg! Text START to setup a new game."
  else
    code = match[1].strip
    if redis.exists("barchuck_game_" + code)
      redis.rpush("barchuck_game_" + code, from)
      assign_player_code from, code
      "You are now playing, drink up, when you're done text BEER"
    else
      "No game with that code. Text START to setup a new game."
    end
  end
end

def beer(from)
  redis = Redis.new
  code = get_code_for_player(from)

  remove_player_from_game(from, code)

  if number_of_players_in_game(from, code) == 1
    loser = redis.lpop "barchuck_game_" + get_code_for_player(from)
    call_loser(loser)
  end

  "Done drinking, you are not the one!"
end

def leave(from)
  redis = Redis.new
  code = get_code_for_player(from)
  remove_player_from_game(from, code)
  redis.del("barchuck_player_" + from)
end

def call_loser(to)

  account_sid = "AC6f3bbde8900c17a6375acbc324cc1bd6"
  auth_token = "31faf02d26340e531f4501628b29283b"

  client = Twilio::REST::Client.new account_sid, auth_token

  call = client.account.calls.create(
    :from => '441212853258',   # From your Twilio number
    :to => to,     # To any number
    # Fetch instructions from this URL when the call connects
    :url => 'http://c9939817.ngrok.io/twiml'
  )

end

def assign_player_code(from, code)
  redis = Redis.new
  redis.set("barchuck_player_" + from, code)
end

def get_code_for_player(from)
  redis = Redis.new
  redis.get("barchuck_player_" + from)
end

def get_game_players(code)
  redis = Redis.new
  redis.lrange("barchuck_game_" + code, 0, -1)
end

def remove_player_from_game(from, code)
  redis = Redis.new
  redis.lrem("barchuck_game_" + code, 0, from)
end

def number_of_players_in_game(from, code)
  redis = Redis.new
  redis.llen("barchuck_game_" + code)
end

#r.Message ChuckNorris.random
