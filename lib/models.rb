require 'digest/sha1'

class TriggerException < Exception; end

class User < ActiveRecord::Base
  has_many :triggers
end

class Trigger < ActiveRecord::Base
  belongs_to :user

  before_validation :generate_hash

  def send_tweet(trigger_json)
    return if self.tweet.nil? # Ensure we have a tweet template

    begin
      trigger = JSON.parse(trigger_json)
      # We currently use the value => value format, but we should change it. this will keep us working, and maintain backward compat.
      Twitter.configure do |config|
        config.consumer_key = $twitter_config[:consumer_key]
        config.consumer_secret = $twitter_config[:consumer_secret]
        config.oauth_token = user.oauth_token
        config.oauth_token_secret = user.oauth_secret
      end

      Twitter.update(tweet_text(trigger))
      $redis.incr TOTAL_JOBS
    rescue Exception => e
      $redis.incr TOTAL_ERRORS
      raise TriggerException, "Error delivering trigger: #{e.inspect}, for trigger: #{trigger_json}"
    end
  end

  private

  def tweet_text(trigger)
    new_value = trigger['triggering_datastream']['value']['current_value'] || trigger['triggering_datastream']['value']['value'] 
    timestamp = trigger['timestamp']
    stream_id = trigger['triggering_datastream']['id']
    feed_id = trigger['environment']['id'].to_s

    self.tweet.gsub('{value}', new_value).
      gsub('{time}', format_time(timestamp)).
      gsub('{datastream}', stream_id).
      gsub('{feed}', feed_id).
      gsub('{feed_url}', "https://cosm.com/feeds/#{feed_id}")
  end
  
  def format_time(time)
    Time.parse(time).strftime('%Y-%m-%d %T')
  end
  
  def generate_hash
    self.hash ||= hash_generator
  end
  
  def hash_generator
    @hashfunc = Digest::SHA1.new
    @hashfunc.update(Time.now.iso8601(6) + rand(100000000).to_s)
    @hashfunc.hexdigest
  end
end

