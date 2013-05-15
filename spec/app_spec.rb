require 'spec_helper'

describe APP_TITLE do
  include Rack::Test::Methods

  def app
    @app ||= Sinatra::Application
  end

  describe "configure" do
    describe "setup_db" do
      it "should setup the db connection" do
        config = { :test => { :adapter => "postgresql", :encoding => "utf8",
          :database => "path", :pool => 5, :username => "user1",
          :password => "passw0rd", :template => "template0", :host => "myhost" } }

        YAML.should_receive(:load_file).with("config/database.yml").and_return(config)
        ActiveRecord::Base.should_receive(:establish_connection).with(
          "adapter"  => 'postgresql',
          "host"     => 'myhost',
          "username" => 'user1',
          "password" => 'passw0rd',
          "database" => 'path',
          "encoding" => 'utf8',
          "pool" => 5,
          "template" => "template0"
        )
        setup_db
      end

      it "should use the environment variable database_uri if provided" do
        db_uri = 'postgres://user1:passw0rd@myhost/path'
        YAML.should_not_receive(:load_file)
        ENV.should_receive(:[]).twice.with('DATABASE_URL').and_return(db_uri)
        ActiveRecord::Base.should_receive(:establish_connection).with(
          :adapter  => 'postgresql',
          :host     => 'myhost',
          :username => 'user1',
          :password => 'passw0rd',
          :database => 'path',
          :encoding => 'utf8'
        )
        setup_db
      end

      it "should throw an error if no db_uri is set and config file is empty" do
        ENV.should_receive(:[]).with('DATABASE_URL').and_return(nil)
        YAML.should_receive(:load_file).with('config/database.yml').and_return(YAML::dump({:test => {}}))

        lambda {
          setup_db
        }.should raise_error
      end
    end

    describe "load_twitter_conf" do
      before(:each) do
        @old_twitter_config = $twitter_config
        @twitter_settings = {"consumer_key" => 'key', "consumer_secret" => 'secret'}
      end

      after(:each) do
        $twitter_config = @old_twitter_config
      end

      it "should setup the twitter omniauth" do
        YAML.should_receive(:load_file).with('config/twitter.yml').and_return({ :test => @twitter_settings })
        load_twitter_conf
        $twitter_config.should == @twitter_settings
      end

      it "should use the environment twitter params if provided" do
        ENV.should_receive(:[]).with('TWITTER_CONSUMER_KEY').twice.and_return('key')
        ENV.should_receive(:[]).with('TWITTER_CONSUMER_SECRET').twice.and_return('secret')
        load_twitter_conf
        $twitter_config.should == @twitter_settings
      end

      it "should throw an error if no twitter config is set" do
        ENV.should_receive(:[]).with('TWITTER_CONSUMER_KEY').and_return(nil)
        YAML.should_receive(:load_file).with('config/twitter.yml').and_return(YAML::dump({}))

        lambda {
          load_twitter_conf
        }.should raise_error
      end
    end

    describe "setup_redis" do
      it "should setup the redis connection" do
        config = { :test => { :host => "127.0.0.1", :port => 6379, :password => "bobbins" } }

        YAML.should_receive(:load_file).with("config/redis.yml").and_return(config)
        Redis.should_receive(:new).with(config[:test])
        setup_redis
      end

      it "should use the environment variable database_uri if provided" do
        redis_uri = 'redis://redis:password@redis.com:9006/'
        YAML.should_not_receive(:load_file)
        ENV.should_receive(:[]).twice.with('REDISTOGO_URL').and_return(redis_uri)
        Redis.should_receive(:new).with({ :host => 'redis.com', :port => 9006, :password => 'password' })
        setup_redis
      end

      it "should throw an error if no redis_uri is set and config file is empty" do
        ENV.should_receive(:[]).with('REDISTOGO_URL').and_return(nil)
        YAML.should_receive(:load_file).with('config/redis.yml').and_return(YAML::dump({:test => {}}))

        lambda {
          setup_redis
        }.should raise_error
      end
    end

    describe "log_level" do
      it "should return a valid log level on being passed a string" do
        log_level("DEBUG").should == Logger::DEBUG
        log_level("debug").should == Logger::DEBUG
        log_level("INFO").should == Logger::INFO
        log_level("info").should == Logger::INFO
        log_level("WARN").should == Logger::WARN
        log_level("warn").should == Logger::WARN
        log_level("ERROR").should == Logger::ERROR
        log_level("error").should == Logger::ERROR
        log_level("FATAL").should == Logger::FATAL
        log_level("fatal").should == Logger::FATAL
        log_level("anythingelse").should == Logger::UNKNOWN
      end
    end
  end

  describe "get /" do
    it "should redirect to xively" do
      get "/"
      last_response.status.should == 302
      last_response.headers['Location'].should == 'https://xively.com'
    end
  end

  describe "post /triggers/:trigger_hash/send" do
    before(:each) do
      @user = User.create!(:twitter_name => 'quentin')
      @trigger = @user.triggers.create!
    end

    it "should send a tweet with the input" do
      Trigger.should_receive(:find_by_hash).with(@trigger.hash).and_return(@trigger)
      @trigger.should_receive(:send_tweet).with('something with urlencoding')
      post "/triggers/#{@user.triggers.last.hash}/send", "body=something%20with%20urlencoding"
      last_response.status.should == 201
    end

    it "should handle trigger exceptions" do
      Trigger.should_receive(:find_by_hash).with(@trigger.hash).and_return(@trigger)
      @trigger.should_receive(:send_tweet).and_raise(TriggerException.new("duplicate tweet"))
      post "/triggers/#{@user.triggers.last.hash}/send", "body=something%20with%20urlencoding"
      last_response.status.should == 400
      last_response.body.should == "Unable to deliver trigger: duplicate tweet"
    end

    it "should handle other exceptions" do
      Trigger.should_receive(:find_by_hash).and_raise(Exception.new("Bad stuff"))
      post "/triggers/#{@user.triggers.last.hash}/send", "body=something"
      last_response.status.should == 500
      last_response.body.should == "Unexpected error occurred: Bad stuff"
    end
  end

  describe "get /stats" do
    before(:each) do
      $redis = double("redis")
      $redis.stub!(:get).and_return(0)
      ENV.stub!(:[]).with('ADMIN_PASSWORD').and_return("password")
    end

    context "when user has admin password" do
      before(:each) do
        authorize 'admin', 'password'
      end

      it "should be successful" do
        get "/stats"
        last_response.status.should == 200
      end

      it "should get our stats from redis" do
        $redis.should_receive(:get).with(TOTAL_JOBS).and_return(123)
        $redis.should_receive(:get).with(TOTAL_ERRORS).and_return(4)
        get "/stats"
      end

      it "should render our csv output" do
        get "/stats"
        last_response.body.should == "total_jobs,total_errors\n0,0\n"
        last_response.headers["Content-Type"].should match(/text\/csv/)
      end
    end

    context "when user doesn't have admin password" do
      it "should not be successful" do
        get "/stats"
        last_response.status.should == 401
      end
    end
  end
end
