# encoding: utf-8

require 'sinatra'
require 'active_record'
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
  Log = Logger.new(STDOUT)
  Log.level = Logger::INFO
  ActiveRecord::Base.logger = Log
end

set :root, File.dirname(__FILE__)

configure :development do
  require 'sqlite3'

  ActiveRecord::Base.establish_connection(
    :adapter  => 'sqlite3',
    :database => 'db/development.db'
  )
end

configure :production do
  creds = YAML.load(ERB.new(File.read('config/database.yml')).result)['production']
  ActiveRecord::Base.establish_connection(creds)
end

class Whisper < ActiveRecord::Base
  def self.trim_table
    connection.execute <<-SQL
DELETE FROM whispers
WHERE id NOT IN (SELECT id FROM whispers ORDER BY created_at DESC LIMIT 50);
    SQL
  end
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
  if env['HTTP_AUTHORIZATION'] == authorization
    Log.info "authorized: #{env['HTTP_AUTHORIZATION']}"
  else
    Log.info "unauthorized: #{env['HTTP_AUTHORIZATION']}"
    error 401
  end

  whisper = Whisper.create(
    :name    => hash['name'],
    :version => hash['version'],
    :url     => hash['project_uri'],
    :info    => hash['info']
  )

  Whisper.trim_table

  Log.info "created whisper: #{whisper.inspect}"

  short_url = Net::HTTP.get(URI.parse("http://is.gd/create.php?format=simple&url=#{URI.escape(whisper.url)}"))
  Log.info "shorted url: #{short_url}"

  whisper_text = "#{whisper.name} (#{whisper.version}): #{short_url} #{whisper.info}"
  whisper_text = whisper_text[0, 120] + '…' if whisper_text.length > 140

  response = Twitter.update(whisper_text)
  Log.info "TWEETED! #{response}"
end
