#!/usr/bin/env ruby
require "rubygems"
require "bundler/setup"
require 'sinatra'
require 'active_record'
require 'yaml'
require 'uri'
require 'twitter'
require 'time'
require 'redis'
require './lib/models'

TOTAL_JOBS = "tweettriggers.total_jobs"
TOTAL_ERRORS = "tweettriggers.total_errors"

def setup_db
  if ENV['DATABASE_URL']
    db_uri = URI.parse(ENV["DATABASE_URL"])

    raise "Error setting up database" if db_uri.nil?

    ActiveRecord::Base.configurations = { settings.environment =>
      {
        :adapter  => db_uri.scheme == 'postgres' ? 'postgresql' : db_uri.scheme,
        :host     => db_uri.host,
        :username => db_uri.user,
        :password => db_uri.password,
        :database => db_uri.path[1..-1],
        :encoding => 'utf8'
      }
    }
  else
    ActiveRecord::Base.configurations = YAML.load_file("config/database.yml").with_indifferent_access
  end

  ActiveRecord::Base.establish_connection(ActiveRecord::Base.configurations[settings.environment])
end

def load_twitter_conf
  $twitter_config = if ENV['TWITTER_CONSUMER_KEY'] && ENV['TWITTER_CONSUMER_SECRET']
    {:consumer_key => ENV['TWITTER_CONSUMER_KEY'], :consumer_secret => ENV['TWITTER_CONSUMER_SECRET']}.with_indifferent_access
  elsif File.exist?('config/twitter.yml')
    YAML.load_file("config/twitter.yml").with_indifferent_access[settings.environment]
  end
  raise "Error loading twitter conf" if $twitter_config.nil?
end

def setup_redis
  if ENV['REDISTOGO_URL']
    redis_uri = URI.parse(ENV['REDISTOGO_URL'])

    raise "Error connecting to Redis" if redis_uri.nil?

    $redis = Redis.new({ :host => redis_uri.host, :port => redis_uri.port,
                        :password => redis_uri.password }.delete_if { |k, v| v.nil? || v.to_s.empty? })
  else
    redis_config = YAML.load_file("config/redis.yml").with_indifferent_access[settings.environment]

    raise "No Redis config found" if redis_config.empty?

    $redis = Redis.new({ :host => redis_config[:host], :port => redis_config[:port],
                         :password => redis_config[:password] }.delete_if { |k, v| v.nil? || v.to_s.empty? })
  end
end

def log_level(level)
  case level.upcase
  when "DEBUG"
    Logger::DEBUG
  when "INFO"
    Logger::INFO
  when "WARN"
    Logger::WARN
  when "ERROR"
    Logger::ERROR
  when "FATAL"
    Logger::FATAL
  else
    Logger::UNKNOWN
  end
end

configure do
  APP_TITLE = "Xively to Twitter"
  load_twitter_conf

  use Rack::Session::Cookie, :key => '_pachube_twitter_triggers',
    :path => '/',
    :expire_after => 2592000, # In seconds
    :secret => ENV['SESSION_SECRET'] || 'our_awesome_secret'

  ENV['LOG_LEVEL'] ||= 'INFO'

  use Rack::Logger, log_level(ENV['LOG_LEVEL'])
  setup_db
  setup_redis
  set :static, true
  set :show_exceptions, false
  set :dump_errors, false
end

helpers do
  def logger
    request.logger
  end

  def protected!
    unless authorized?
      response['WWW-Authenticate'] = %(Basic realm="Restricted Area")
      throw(:halt, [401, "Not authorized\n"])
    end
  end

  def authorized?
    @auth ||=  Rack::Auth::Basic::Request.new(request.env)
    ENV['ADMIN_PASSWORD'] && @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == ['admin', ENV['ADMIN_PASSWORD']]
  end
end

error TriggerException do
  logger.warn("[ERROR] - Error sending trigger: #{env['sinatra.error'].message}")

  status 400
  "Unable to deliver trigger: #{env['sinatra.error'].message}"
end

error do
  logger.warn("[ERROR] - Unexpected error: #{env['sinatra.error'].inspect}")
  status 500
  "Unexpected error occurred: #{env['sinatra.error'].message}"
end

get '/' do
  redirect 'https://xively.com'
end

# Send trigger
post '/triggers/:trigger_hash/send' do
  @trigger = Trigger.find_by_hash(params[:trigger_hash])
  @trigger.send_tweet(params[:body])
  201
end

get '/stats' do
  protected!
  content_type :csv

  csv = <<-CSV
total_jobs,total_errors
#{$redis.get(TOTAL_JOBS).to_i},#{$redis.get(TOTAL_ERRORS).to_i}
CSV
  csv
end
