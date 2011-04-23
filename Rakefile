require File.expand_path('../gemwhisperer', __FILE__)

namespace :db do
  desc 'Migrate the database'
  task :migrate do
    ActiveRecord::Migrator.migrate('db/migrate')
  end
end

desc 'Create a global RubyGems webhook, specify HOST'
task :hook do
  uri = URI.parse('http://rubygems.org/api/v1/web_hooks')
  http = Net::HTTP.new(uri.host, uri.port)
  request = Net::HTTP::Post.new(uri.path)
  request.initialize_http_header('Authorization' => ENV['RUBYGEMS_API_KEY'])
  request.set_form_data(:gem_name => '*', :url => ENV['HOST'].to_s + '/hook')
  response = http.request(request)
  puts response.msg
end
