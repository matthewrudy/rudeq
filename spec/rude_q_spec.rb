require File.dirname(__FILE__) + '/spec_helper'

describe RudeQ::ClassMethods do # ProcessQueue extends ClassMethods
  before(:each) do
    ProcessQueue.delete_all
    ProcessQueue.raise_on_processed = false
    create_some_noise
  end
  
  def create_some_noise
    ProcessQueue.create!(:queue_name => "doNT use this in Specs", :data => {:not => "to be messed with"})
    ProcessQueue.create!(:queue_name => "abcde", :data => {:same_as => "the specs but already processed"}, :processed => true)
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
    it "should work with integers" do
      ProcessQueue.set('abcde', 7816327370)
      ProcessQueue.get('abcde').should == 7816327370
    end
    it "unfortunately doesnt resolve booleans correctly" do
      ProcessQueue.set('abcde', true)
      ProcessQueue.get('abcde').should == 1
      
      ProcessQueue.set('abcde', false)
      ProcessQueue.get('abcde').should == 0
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
    it "should revert a record if something goes wrong before it finishes" do
      ProcessQueue.raise_on_processed = true
      ProcessQueue.set('abcde', :this_will_remain_unprocessed)
      
      # confirm the object is in the db
      record = ProcessQueue.find(:first, :order => "id DESC")
      record.queue_name.should == 'abcde'
      record.data.should == :this_will_remain_unprocessed
      record.processed?.should == false
      record.token.should == nil
      
      lambda {ProcessQueue.get('abcde')}.should raise_error(RuntimeError)
      
      record.reload
      record.queue_name.should == 'abcde'
      record.data.should == :this_will_remain_unprocessed
      record.processed?.should == false
      record.token.should == nil
    end
  end
  
  describe "queue_options" do
    describe :processed do
      describe "set to :destroy" do
        before(:each) do
          @old_processed = ProcessQueue.queue_options[:processed]
          ProcessQueue.queue_options[:processed] = :destroy
        end
        after(:each) do
          ProcessQueue.queue_options[:processed] = @old_processed
        end
        it "should delete processed items" do
          count = ProcessQueue.count
          
          ProcessQueue.set(:abcde, "some value")
          ProcessQueue.count.should == (count + 1)
          
          ProcessQueue.get(:abcde).should == "some value"
          ProcessQueue.count.should == count
        end
      end
      describe "set to something crazy" do
        before(:each) do
          @old_processed = ProcessQueue.queue_options[:processed]
          ProcessQueue.queue_options[:processed] = :something_crazy
        end
        after(:each) do
          ProcessQueue.queue_options[:processed] = @old_processed
        end
        it "should raise an exception" do
          ProcessQueue.set(:abcde, "some value")
          lambda {ProcessQueue.get(:abcde)}.should raise_error(ArgumentError)
        end
      end
    end
  end
  
  describe ".backlog" do
    it "should count the unprocessed items for the provided queue_name" do
      ProcessQueue.backlog(:abcde).should == 0
      
      ProcessQueue.set(:abcde, "a value")
      ProcessQueue.backlog(:abcde).should == 1
      
      ProcessQueue.set(:something_else, "another value")
      3.times { ProcessQueue.set(:abcde, :add_three_more)}
      
      ProcessQueue.backlog(:abcde).should == 4
      
      ProcessQueue.get(:abcde).should == "a value"
      ProcessQueue.backlog(:abcde).should == 3
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
  
  # it "should not return a processed item with the same token" do
  #   @token = "tokEEEannn"
  # 
  #   RudeQ::TokenLock.should respond_to(:get_unique_token) # ensure our stub is safe
  #   RudeQ::TokenLock.should_receive(:get_unique_token).exactly(3).times.and_return(@token)
  # 
  #   @existing = ProcessQueue.create!(:queue_name => 'abcde', :data => :old_data, :token => @token, :processed => true)
  # 
  #   ProcessQueue.get('abcde').should be(nil)
  #     
  #   ProcessQueue.set('abcde', :new_data)
  #   ProcessQueue.get('abcde').should == :new_data
  #   ProcessQueue.get('abcde').should be(nil)
  # end
  
end
