require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe User do
  before(:each) do
    @user = User.create!(:twitter_name => 'TheRealRickAstley')
  end

  it "should have a twitter_name attribute" do
    @user.twitter_name.should == 'TheRealRickAstley'
  end

  it "should have a triggers association" do
    @user.triggers.create!
    @user.triggers.count.should == 1
    @user.triggers.should be_an_instance_of(Array)
    @user.triggers.each do |trigger|
      trigger.should be_an_instance_of(Trigger)
    end
  end
end

describe Trigger do
  before(:each) do
    @user = User.create!(:twitter_name => 'TheRealRickAstley')
    @trigger = @user.triggers.create!(
      :tweet => '{value}, {time}, {datastream}, {feed}, {feed_url} #cosm'
    )
  end

  it "should belong to a user" do
    @trigger.user.should be_an_instance_of(User)
    @trigger.user.twitter_name.should == 'TheRealRickAstley'
  end

  it "should not find the trigger if searched for by another user" do
    user2 = User.create!(:twitter_name => 'FakeRick')
    trigger2 = user2.triggers.create!(
      :tweet => '{value}, {time}, {datastream}, {feed}, {feed_url}'
    )
    @user.triggers.find_by_hash(trigger2.hash).should be_nil
  end

  context "validation" do
    it "should generate the hash before validation" do
      @trigger.hash = nil
      @trigger.valid?
      @trigger.hash.should match(/\w+/)
    end

    it "should not overwrite existing hash" do
      hash = @trigger.hash
      @trigger.hash.should_not be_nil
      @trigger.valid?
      @trigger.hash.should == hash
    end
  end

  context "#send_tweet" do
    it "should render the tweet and send it to Twitter" do
      now_time = Time.now
      Twitter.should_receive(:update).with("09120, #{now_time.strftime('%Y-%m-%d %T')}, myStreamId1, 504, https://xively.com/feeds/504 #xively")
      @trigger.send_tweet({
        'environment' => {
          'id' => 504
        },
        'triggering_datastream' => {
          'id' => 'myStreamId1',
          'value' => {
            'current_value' => '09120'
          }
        },
        'timestamp' => now_time.iso8601(6)
      }.to_json)
    end

    it "should not send a tweet if the tweet text is nil" do
      now_time = Time.now
      Twitter.should_not_receive(:update)
      @trigger.tweet = nil
      @trigger.send_tweet('{}')
    end

    context "exceptions" do
      it "should throw an exception if Twitter.update raises an error" do
        now_time = Time.now
        Twitter.should_receive(:update).with("09120, #{now_time.strftime('%Y-%m-%d %T')}, myStreamId1, 504, https://xively.com/feeds/504 #xively").and_raise(TriggerException)
        expect {
          @trigger.send_tweet({
            'environment' => {
              'id' => 504
            },
            'triggering_datastream' => {
              'id' => 'myStreamId1',
              'value' => {
                'current_value' => '09120'
              }
            },
            'timestamp' => now_time.iso8601(6)
          }.to_json)
        }.to raise_error(TriggerException)
      end

      it "should not raise an exception if passed invalid JSON" do
        expect {
          @trigger.send_tweet("this is not json")
        }.to raise_error(TriggerException)
      end
    end
  end
end
