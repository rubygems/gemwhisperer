# encoding: utf-8

require 'sinatra'
require 'active_record'
require 'sqlite3'
require 'twitter'
require 'json'

require 'yaml'
require 'logger'
require 'digest/sha2'
require 'net/http'
require 'uri'

if File.exist?('config/application.yml')
  config = YAML.load_file('config/application.yml')
  config.each{|k,v| ENV[k] = v }
end

Twitter.configure do |config|
  config.consumer_key       = ENV['CONSUMER_KEY']
  config.consumer_secret    = ENV['CONSUMER_SECRET']
  config.oauth_token        = ENV['REQUEST_TOKEN']
  config.oauth_token_secret = ENV['REQUEST_SECRET']
end

configure do
  Log = Logger.new("log/#{ENV['RACK_ENV']}.log")
  Log.level = Logger::INFO
  ActiveRecord::Base.logger = Log
end

configure :development do
  ActiveRecord::Base.establish_connection(
    :adapter  => 'sqlite3',
    :database => 'db/development.db'
  )
end

configure :production do
  creds = YAML.load_file('config/database.yml')['production']
  ActiveRecord::Base.establish_connection(creds)
end

class Whisper < ActiveRecord::Base
end

get '/' do
  @whispers = Whisper.order('created_at DESC').limit(25)
  erb :index
end

post '/hook' do
  data = request.body.read
  Log.info "got webhook: #{data}"

  hash = JSON.parse(data)
  Log.info "parsed json: #{hash.inspect}"

  authorization = Digest::SHA2.hexdigest(hash['name'] + hash['version'] + ENV['RUBYGEMS_API_KEY'])
  if headers['Authorization'] == authorization
    Log.info "authorized: #{headers['Authorization']}"
  else
    Log.info "unauthorized: #{headers['Authorization']}"
    error 401
  end

  whisper = Whisper.create(
    :name    => hash['name'],
    :version => hash['version'],
    :url     => hash['project_uri'],
    :info    => hash['info']
  )
  Log.info "created whisper: #{whisper.inspect}"

  short_url = Net::HTTP.get(URI.parse("http://is.gd/create.php?format=simple&url=#{URI.escape(whisper.url)}"))
  Log.info "shorted url: #{short_url}"

  whisper_text = "#{whisper.name} (#{whisper.version}): #{short_url} #{whisper.info}"
  whisper_text = whisper_text[0, 139] + '…' if whisper_text.length > 140

  response = Twitter.update(whisper_text)
  Log.info "TWEETED! #{response}"
end
