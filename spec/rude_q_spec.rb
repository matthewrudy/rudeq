require File.dirname(__FILE__) + '/spec_helper'

describe RudeQ::ClassMethods do # ProcessQueue extends ClassMethods
  before(:each) do
    ProcessQueue.delete_all
    create_some_noise
  end
  
  def create_some_noise
    ProcessQueue.create!(:queue_name => "doNT use this in Specs", :data => {:not => "to be messed with"})
    ProcessQueue.create!(:queue_name => "abcde", :data => {:same_as => "the specs but already processed"}, :processed => true)
    ProcessQueue.create!(:queue_name => "abcde", :data => {:same_as => "the specs but with token"}, :token => "    unlikely    ")
  end
  
  describe "get and set" do
    it "should work with strings" do
      ProcessQueue.set('abcde', "Something to set")
      ProcessQueue.get('abcde').should == "Something to set"
    end
    it "should work with symbols" do
      ProcessQueue.set('abcde', :a_symbol)
      ProcessQueue.get('abcde').should == :a_symbol
    end
    it "should work with arrays" do
      array = [1, :b, "C"]
      ProcessQueue.set('abcde', array)
      ProcessQueue.get('abcde').should == array
    end
    it "should work with hashes" do
      hash = {:symbol => "A string", "stringy" => 23, 74 => :cheese}
      ProcessQueue.set('abcde', hash)
      ProcessQueue.get('abcde').should == hash
    end
    
    it "should :get in the same order they are :set" do
      ProcessQueue.set('abcde', :first)
      ProcessQueue.set('abcde', "second")
      
      ProcessQueue.get('abcde').should == :first
      
      ProcessQueue.set('abcde', 33.3333)
      
      ProcessQueue.get('abcde').should == "second"
      ProcessQueue.get('abcde').should == 33.3333
      ProcessQueue.get('abcde').should be(nil)
    end
    
    it "should keep queues seperated" do
      ProcessQueue.set('queue_1', :data_1)
      ProcessQueue.set('queue_2', "DATA2")
      
      ProcessQueue.get('queue_2').should == "DATA2"
      ProcessQueue.get('queue_2').should be(nil)
      ProcessQueue.get('queue_1').should == :data_1
      ProcessQueue.get('queue_1').should be(nil)
    end
    
    it "should call to_s on inputs" do
      qname = stub("fake input")
      qname.should_receive(:to_s).exactly(:twice).and_return("fake queue name")
      
      ProcessQueue.set(qname, ["Data"])
      ProcessQueue.get(qname).should == ["Data"]
    end
    
    it "should work with queue name as strings or symbols" do
      ProcessQueue.set(:bah, "something about bah")
      ProcessQueue.get("bah").should == "something about bah"
      
      ProcessQueue.set("girah", {:craziness => "embodied"})
      ProcessQueue.get(:girah).should == {:craziness => "embodied"}
    end
  end
  
  describe ".set" do
    it "should delegate to :create!" do
      ProcessQueue.should_receive(:create!).with(:queue_name => 'abcde', :data => :magical_planet)
      ProcessQueue.set('abcde', :magical_planet)
    end
    it "should return nil" do
      ProcessQueue.set('abcde', "something").should be(nil)
    end
  end
  
  describe ".get" do
    it "should not return a processed item with the same token" do
      @token = "tokEEEannn"

      RudeQ::TokenLock.should respond_to(:get_unique_token) # ensure our stub is safe
      RudeQ::TokenLock.should_receive(:get_unique_token).exactly(3).times.and_return(@token)

      @existing = ProcessQueue.create!(:queue_name => 'abcde', :data => :old_data, :token => @token, :processed => true)

      ProcessQueue.get('abcde').should be(nil)
        
      ProcessQueue.set('abcde', :new_data)
      ProcessQueue.get('abcde').should == :new_data
      ProcessQueue.get('abcde').should be(nil)
    end
    
    it ", unfortunately, should not revert a record if something goes wrong before it finishes" do
      ProcessQueue.should_receive(:processed!).and_raise(RuntimeError)
      ProcessQueue.set('abcde', :this_will_remain_tokenised)
      
      # confirm the object is in the db
      record = ProcessQueue.find(:first, :order => "id DESC")
      record.queue_name.should == 'abcde'
      record.data.should == :this_will_remain_tokenised
      record.processed?.should == false
      record.token.should == nil
      
      lambda {ProcessQueue.get('abcde')}.should raise_error(RuntimeError)
      
      record.reload
      record.queue_name.should == 'abcde'
      record.data.should == :this_will_remain_tokenised
      record.processed?.should == false
      record.token.should_not == nil
    end
  end

  describe ".cleanup!" do
    it "should use :delete_all" do
      ProcessQueue.should_receive(:delete_all) # not :destroy_all
      ProcessQueue.cleanup!
    end
    
    it "should allow string inputs" do
      ProcessQueue.cleanup!("3600")
    end
    
    it "should allow integer inputs" do
      ProcessQueue.cleanup!(3600)
    end
    
    it "should not clear unprocessed items" do
      ProcessQueue.set('abcde', :giraffe)
      ProcessQueue.set('abcde', :monkey)
      ProcessQueue.count.should >= 2
      
      ProcessQueue.cleanup!
      
      ProcessQueue.count.should >=2
      ProcessQueue.get('abcde').should == :giraffe
    end
    
    it "should not clear old unprocessed items" do
      ProcessQueue.set('abcde', :giraffe)
      giraffe = ProcessQueue.find(:first, :conditions => {:data => :giraffe})
      
      time_now = Time.now
      Time.stub!(:now).and_return(time_now + 1.year)
      
      giraffe.updated_at.should < 2.weeks.ago
      
      ProcessQueue.cleanup!
      
      giraffe.reload
      ProcessQueue.get('abcde').should == :giraffe
    end
    
    it "should not clear processed items newer than the argument" do
      ProcessQueue.set('abcde', :giraffe)
      ProcessQueue.get('abcde').should == :giraffe
      
      giraffe = ProcessQueue.find(:first, :conditions => {:data => :giraffe})
      
      time_now = Time.now
      Time.stub!(:now).and_return(time_now + 1.week - 5.minutes)
      
      giraffe.updated_at.should > 1.week.ago
      giraffe.processed.should be(true)
      
      ProcessQueue.cleanup!(1.week)
      
      giraffe.reload
    end
    
    it "should not clear processed items newer than one hour, by default" do
      ProcessQueue.set('abcde', :giraffe)
      ProcessQueue.get('abcde').should == :giraffe
      
      giraffe = ProcessQueue.find(:first, :conditions => {:data => :giraffe})
      
      time_now = Time.now
      Time.stub!(:now).and_return(time_now + 59.minutes)
      
      giraffe.updated_at.should > 1.hour.ago
      giraffe.processed.should be(true)
      
      ProcessQueue.cleanup!()
      
      giraffe.reload
    end
    
    it "should clear processed items older than the argument" do
      ProcessQueue.set('abcde', :giraffe)
      ProcessQueue.get('abcde').should == :giraffe
      
      giraffe = ProcessQueue.find(:first, :conditions => {:data => :giraffe})
      
      time_now = Time.now
      Time.stub!(:now).and_return(time_now + 1.week + 5.minutes)
      
      giraffe.updated_at.should < 1.week.ago
      giraffe.processed.should be(true)
      
      ProcessQueue.cleanup!(1.week)
      
      lambda { giraffe.reload }.should raise_error(ActiveRecord::RecordNotFound)
    end
    
    it "should clear processed items older than one hour, by default" do
      ProcessQueue.set('abcde', :giraffe)
      ProcessQueue.get('abcde').should == :giraffe
      
      giraffe = ProcessQueue.find(:first, :conditions => {:data => :giraffe})
      
      time_now = Time.now()
      Time.stub!(:now).and_return(time_now + 61.minutes)
      
      giraffe.updated_at.should < 1.hour.ago
      giraffe.processed.should be(true)
      
      ProcessQueue.cleanup!
      
      lambda { giraffe.reload }.should raise_error(ActiveRecord::RecordNotFound)
    end
  end
end

describe RudeQ::TokenLock do

  describe ".get_unique_token" do
    it "should create a unique token" do
      lots_of_tokens = Array.new(50) do
        RudeQ::TokenLock.get_unique_token
      end
      lots_of_tokens.uniq.should == lots_of_tokens
    end
    
    it "should create a unique token even if time stands still" do
      time_now = Time.now
      Time.should_receive(:now).at_least(50).times.and_return(time_now)
      lots_of_tokens = Array.new(50) do
        RudeQ::TokenLock.get_unique_token
      end
      lots_of_tokens.uniq.should == lots_of_tokens
    end
  end
  
end
