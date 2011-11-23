#!/usr/bin/env ruby
require "rubygems"
require "bundler/setup"
require 'sinatra'
require 'active_record'
require 'rack-flash'
require 'yaml'
require 'uri'
require 'twitter'
require 'twitter_oauth'
require 'time'
require './lib/models'

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
  APP_TITLE = "Pachube to Twitter"
  load_twitter_conf

  use Rack::Session::Cookie, :key => '_pachube_twitter_triggers',
    :path => '/',
    :expire_after => 2592000, # In seconds
    :secret => ENV['SESSION_SECRET'] || 'our_awesome_secret'

  ENV['LOG_LEVEL'] ||= 'INFO'

  use Rack::Flash
  use Rack::Logger, log_level(ENV['LOG_LEVEL'])
  setup_db
  set :static, true
end

helpers do
  def logger
    request.logger
  end
end

def require_login
  redirect '/login' if @user.nil?
end

before do
  logger.debug("Session: #{session.inspect}")
  @user = User.find_by_twitter_name(session[:user]) if session[:user]
  @client = TwitterOAuth::Client.new(
    :consumer_key => $twitter_config[:consumer_key],
    :consumer_secret => $twitter_config[:consumer_secret],
    :token => session[:access_token],
    :secret => session[:secret_token]
  )
end

get '/' do
  redirect 'https://pachube.com'
end

# Authenticate the user if necessary
get '/login' do
  redirect '/triggers/new' if @user
  @trigger = Trigger.find_by_hash(session[:trigger_hash]) if session[:trigger_hash]
  erb :auth
end

# New trigger
get '/triggers/new' do
  require_login
  logger.debug("Attempting to create trigger for user: #{session[:user]}")
  erb :new
end

# Create trigger
post '/triggers' do
  require_login
  @trigger = @user.triggers.create(:tweet => (params['tweet'] || '').strip)
  content_type :json
  {'trigger_hash' => @trigger.hash}.to_json
end

# Edit trigger
get '/triggers/:trigger_hash/edit' do
  session[:trigger_hash] = params[:trigger_hash]
  require_login
  @trigger = @user.triggers.find_by_hash(params[:trigger_hash])
  if @trigger.nil?
    session.clear
    # hang onto the trigger hash, so we can edit it after performing authentication with twitter
    session[:trigger_hash] = params[:trigger_hash]
    redirect '/login'
  else
    erb :edit
  end
end

# Update trigger
put '/triggers/:trigger_hash' do
  require_login
  @trigger = @user.triggers.find_by_hash(params[:trigger_hash])
  if @trigger.nil?
    session.clear
    # hang onto the trigger hash, so we can edit it after performing authentication with twitter
    session[:trigger_hash] = params[:trigger_hash]
    redirect '/login'
  else
    @trigger.tweet = params['tweet'].strip
    @trigger.save!
    content_type :json
    {'trigger_hash' => @trigger.hash}.to_json
  end
end

# Delete trigger
delete '/triggers/:trigger_hash' do
  require_login
  @trigger = @user.triggers.find_by_hash(params[:trigger_hash])
  if @trigger.nil?
    session.clear
    # hang onto the trigger hash, so we can edit it after performing authentication with twitter
    session[:trigger_hash] = params[:trigger_hash]
    redirect '/login'
  else
    @trigger.destroy
    200
  end
end

# Send trigger
post '/triggers/:trigger_hash/send' do
  @trigger = Trigger.find_by_hash(params[:trigger_hash])
  @trigger.send_tweet(params[:body])
  201
end

# store the request tokens and send to Twitter
get '/auth/twitter' do
  request_token = @client.request_token(
    :oauth_callback => url('/auth/twitter/callback')
  )
  session[:request_token] = request_token.token
  session[:request_token_secret] = request_token.secret
  redirect request_token.authorize_url
end

# auth URL is called by twitter after the user has accepted the application
# this is configured on the Twitter application settings page
get '/auth/twitter/callback' do
  # Exchange the request token for an access token.
  begin
    @access_token = @client.authorize(
      session[:request_token],
      session[:request_token_secret],
      :oauth_verifier => params[:oauth_verifier]
    )

    if @client.authorized?
      # Storing the access tokens so we don't have to go back to Twitter again
      # in this session.  In a larger app you would probably persist these details somewhere.
      session[:access_token] = @access_token.token
      session[:secret_token] = @access_token.secret

      @user = User.find_or_create_by_twitter_name(@access_token.params[:screen_name])
      logger.debug("User: #{@user.inspect}")
      @user.oauth_token = @access_token.token
      @user.oauth_secret = @access_token.secret
      @user.save!

      session[:user] = @user.twitter_name

      @trigger = @user.triggers.find_by_hash(session[:trigger_hash]) if session[:trigger_hash]
      logger.debug("Trigger: #{@trigger}")

      erb :success
    else
      erb :failure
    end

  rescue OAuth::Unauthorized => exception
    erb :failure
  end
end

get '/auth/failure' do
  @msg = "Failed to authenticate with Twitter. Please try again."
  erb :auth
end

post '/auth/twitter/unauthenticate' do
  session.clear
  redirect '/login'
end
