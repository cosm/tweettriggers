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

  describe "get /triggers/new" do
    context "user logged in" do
      before(:each) do
        @user = User.new(:twitter_name => 'quentin')
        @rack_env = {'rack.session' => {'user' => @user.twitter_name}}
        User.stub!(:find_by_twitter_name).and_return(@user)
      end

      it "should render the index template" do
        get "/triggers/new", nil, @rack_env
        last_response.status.should == 200
        last_response.body.should include('<form action="" method="post" id="tweetform">')
      end
    end

    context "user not logged in" do
      it "should render :auth" do
        get "/triggers/new"
        last_response.status.should == 200
        last_response.body.should include('Authenticate with Twitter')
      end
    end
  end

  describe "post /triggers" do
    context "user logged in" do
      before(:each) do
        @user = User.create!(:twitter_name => 'quentin')
        @rack_env = {'rack.session' => {'user' => @user.twitter_name}}
        User.stub!(:find_by_twitter_name).and_return(@user)
      end

      it "should create a new trigger for the user" do
        count = @user.triggers.count
        post "/triggers", nil, @rack_env
        @user.triggers.count.should == count+1
      end

      it "should save the trigger's tweet text" do
        post "/triggers", {'tweet' => 'something_new'}, @rack_env
        @user.triggers.last.tweet.should == "something_new"
      end

      it "should return the new trigger as json" do
        post "/triggers", nil, @rack_env
        last_response.status.should == 200
        json = JSON.parse(last_response.body)
        json['trigger_hash'].should_not be_blank
        json['trigger_hash'].should == @user.triggers.last.hash
      end
    end

    context "user not logged in" do
      it "should render :auth" do
        post "/triggers"
        last_response.status.should == 200
        last_response.body.should include('Authenticate with Twitter')
      end
    end
  end

  describe "get /triggers/:trigger_hash/edit" do
    context "user logged in" do
      before(:each) do
        @user = User.create!(:twitter_name => 'quentin')
        @rack_env = {'rack.session' => {'user' => @user.twitter_name}}
        User.stub!(:find_by_twitter_name).and_return(@user)
        @user.triggers.create!
      end

      it "should render the edit form for the trigger" do
        get "/triggers/#{@user.triggers.last.hash}/edit", nil, @rack_env
        last_response.status.should == 200
        last_response.body.should include('<form action="" method="post" id="tweetform">')
      end
    end

    context "wrong user logged in" do
      before(:each) do
        @bob = User.create!(:twitter_name => 'bob')
        @alice = User.create!(:twitter_name => 'alice')
        @rack_env = { 'rack.session' => { 'user' => @bob.twitter_name } }
        User.stub!(:find_by_twitter_name).and_return(@alice)
        @trigger = @bob.triggers.create!
      end

      it "should render :auth" do
        get "/triggers/#{@trigger.hash}/edit", nil, @rack_env
        last_response.status.should == 200
        last_response.body.should include('Authenticate with Twitter')
      end

      it "should keep the trigger_hash in the session" do
        get "/triggers/#{@trigger.hash}/edit", nil, @rack_env
        last_request.env['rack.session']['trigger_hash'].should == @trigger.hash
      end

      it "should load the trigger object when rendering login" do
        Trigger.should_receive(:find_by_hash).with(@trigger.hash).and_return(@trigger)
        get "/triggers/#{@trigger.hash}/edit", nil, @rack_env
      end
    end


    context "user not logged in" do
      it "should render :auth" do
        get "/triggers/asdf1234/edit"
        last_response.status.should == 200
        last_response.body.should include('Authenticate with Twitter')
      end
    end
  end

  describe "put /triggers/:trigger_hash" do
    before(:each) do
      @user = User.create!(:twitter_name => 'quentin')
      @user.triggers.create!
    end

    context "user logged in" do
      before(:each) do
        @rack_env = {'rack.session' => {'user' => @user.twitter_name}}
        User.stub!(:find_by_twitter_name).and_return(@user)
      end

      it "should update the trigger 'tweet' param" do
        put "/triggers/#{@user.triggers.last.hash}", {'tweet' => 'something_new'}, @rack_env
        @user.triggers.last.tweet.should == "something_new"
      end

      it "should strip spaces off the tweet param before saving it" do
        put "/triggers/#{@user.triggers.last.hash}", {'tweet' => '   spacely sprockets       '}, @rack_env
        @user.triggers.last.tweet.should == "spacely sprockets"
      end

      it "should render the trigger_hash into body json" do
        put "/triggers/#{@user.triggers.last.hash}", {'tweet' => 'something_new'}, @rack_env
        last_response.status.should == 200
        json = JSON.parse(last_response.body)
        json["trigger_hash"].should_not be_blank
        json["trigger_hash"].should == @user.triggers.last.hash
      end
    end

    context "wrong user logged in" do
      before(:each) do
        @alice = User.create!(:twitter_name => "alice")
        @rack_env = { 'rack.session' => { 'user' => @alice.twitter_name }}
        User.stub!(:find_by_twitter_name).and_return(@alice)
      end

      it "should render :auth" do
        put "/triggers/#{@user.triggers.last.hash}", { 'tweet' => 'something new' }, @rack_env
        last_response.status.should == 200
        last_response.body.should include('Authenticate with Twitter')
      end

      it "should not update the trigger" do
        put "/triggers/#{@user.triggers.last.hash}", {'tweet' => 'something_new'}, @rack_env
        @user.triggers.last.tweet.should_not == "something_new"
      end
    end

    context "user not logged in" do
      it "should render :auth" do
        put "/triggers/#{@user.triggers.last.hash}"
        last_response.status.should == 200
        last_response.body.should include('Authenticate with Twitter')
      end
    end
  end

  describe "delete /triggers/:trigger_hash" do
    before(:each) do
      @user = User.create!(:twitter_name => 'quentin')
      @user.triggers.create!
      @rack_env = {}
    end

    it "should destroy the trigger" do
      count = @user.triggers.count
      delete "/triggers/#{@user.triggers.last.hash}", nil, @rack_env
      last_response.status.should == 200
      @user.triggers.count.should == count - 1
    end

    it "should render :auth if the trigger is not found" do
      count = @user.triggers.count
      delete "/triggers/#{@user.triggers.last.hash}rubbish", nil, @rack_env
      last_response.status.should == 200
      last_response.body.should include("Authenticate with Twitter")
      @user.triggers.count.should == count
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

  describe "get /auth/twitter" do
    it " should fetch a request token, store it in the session, and redirect" do
      @client = mock(Object)
      response = mock(Object, :token => 'token', :secret => 'secret', :authorize_url => 'our/auth/url')
      TwitterOAuth::Client.should_receive(:new).and_return(@client)
      @client.should_receive(:request_token).with(:oauth_callback => 'http://example.org/auth/twitter/callback').and_return(response)
      get "/auth/twitter"
      last_response.status.should == 302
      last_request.env['rack.session']['request_token'].should == 'token'
      last_request.env['rack.session']['request_token_secret'].should == 'secret'
      last_response.headers['Location'].should == 'http://example.org/our/auth/url'
    end
  end

  describe "get /auth/twitter/callback" do
  
    def get_twitter_callback
      get "/auth/twitter/callback", @rack_params, @rack_env
    end
    
    context "if successful" do
      before(:each) do
        @rack_params = {
          'oauth_token' => 'abcd1234'
        }
        @rack_env = {
        }
  
        @access_token = mock(Object, :token => 'token', :secret => 'secret', :params => {:screen_name => 'quentin'})
        @client = mock(Object, :authorize => @access_token, :authorized? => true)
        TwitterOAuth::Client.should_receive(:new).and_return(@client)
      end
  
      it "should find a user if one exists" do
        @quentin = User.create!(:twitter_name => 'quentin')
        User.count.should == 1
        get_twitter_callback
        last_response.status.should == 200
        User.count.should == 1
      end
  
      it "should create a new user if none exists" do
        User.count.should == 0
        get_twitter_callback
        last_response.status.should == 200
        User.count.should == 1
        User.find_by_twitter_name('quentin').should be_instance_of(User)
      end
  
      it "should log the user in" do
        get_twitter_callback
        last_request.env['rack.session']['user'].should == 'quentin'
      end
  
      it "should store the user's oauth token & secret into the session" do
        get_twitter_callback
        last_request.env['rack.session']['access_token'].should == 'token'
        last_request.env['rack.session']['secret_token'].should == 'secret'
      end

      # So we can use it later when we send their triggers
      it "should store the user's oauth token & secret into the user model" do
        get_twitter_callback
        user = User.find_by_twitter_name('quentin')
        user.oauth_token.should == 'token'
        user.oauth_secret.should == 'secret'
      end
  
      it "should render the success template" do
        get_twitter_callback
        last_response.status.should == 200
        last_response.body.should include("<h1>Successfully authenticated</h1>")
      end
    end    
    
    context "if not successful" do
      before(:each) do
        @rack_params = {
          'oauth_token' => 'abcd1234'
        }
        @rack_env = {
        }
  
        #@access_token = mock(Object, :token => 'token', :secret => 'secret', :params => {:screen_name => 'quentin'})
        #@client = mock(Object, :authorize => @access_token, :authorized? => true)
        #TwitterOAuth::Client.should_receive(:new).and_return(@client)
      end
      
      it "should render the failure template" do
        client = mock(Object, :authorize => true, :authorized? => false)
        TwitterOAuth::Client.should_receive(:new).and_return(client)
        get_twitter_callback
        last_response.status.should == 200
        last_response.body.should include("<h1>Failed to authenticate</h1>")
      end
      
      it "should render the failure template if it raised an exception" do
        client = mock(Object, :authorized? => true)
        client.should_receive(:authorize).and_raise(OAuth::Unauthorized)
        TwitterOAuth::Client.should_receive(:new).and_return(client)
        get_twitter_callback
        last_response.status.should == 200
        last_response.body.should include("<h1>Failed to authenticate</h1>")
      end
    end
  end

  describe "post /auth/twitter/unauthenticate" do
    context "user logged in" do
      before(:each) do
        @user = User.new(:twitter_name => 'quentin')
        User.stub!(:find_by_twitter_name).and_return(@user)
        @rack_env = { 'rack.session' => { 'user' => @user.twitter_name, 'access_token' => 'token', 'secret_token' => 'secret' } }
      end

      it "should render :auth" do
        post "/auth/twitter/unauthenticate"
        last_response.status.should == 200
        last_response.body.should include('Authenticate with Twitter')
      end

      it "should clear the session" do
        post "/auth/twitter/unauthenticate"
        last_request.env['rack.session']['access_token'].should be_nil #== 'token'
        last_request.env['rack.session']['secret_token'].should be_nil #== 'secret'
      end
    end

    context "user not logged in" do
      it "should render :auth" do
        post "/auth/twitter/unauthenticate"
        last_response.status.should == 200
        last_response.body.should include('Authenticate with Twitter')
      end
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
