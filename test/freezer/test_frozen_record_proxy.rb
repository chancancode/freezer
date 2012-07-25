require 'minitest_helper'
require 'freezer/frozen_record_proxy'

module Freezer
  describe FrozenRecordFactory do
    describe ".get_class" do
      it "should understand class names as strings" do
        FrozenRecordFactory.get_class('array').must_equal Array
        FrozenRecordFactory.get_class('hash').must_equal Hash
        FrozenRecordFactory.get_class('stand_in_model').must_equal StandInModel

        FrozenRecordFactory.get_class('Array').must_equal Array
        FrozenRecordFactory.get_class('Hash').must_equal Hash
        FrozenRecordFactory.get_class('StandInModel').must_equal StandInModel
      end

      it "should understand class names as symbol" do
        FrozenRecordFactory.get_class(:array).must_equal Array
        FrozenRecordFactory.get_class(:hash).must_equal Hash
        FrozenRecordFactory.get_class(:stand_in_model).must_equal StandInModel
      end

      it "should understand class names as constants" do
        FrozenRecordFactory.get_class(Array).must_equal Array
        FrozenRecordFactory.get_class(Hash).must_equal Hash
        FrozenRecordFactory.get_class(StandInModel).must_equal StandInModel
      end
    end

    describe ".build" do
      it "should know how to build a frozen record" do
        attributes = { key1: 'value1', key2: true, key3: 1 }
        FrozenRecordFactory.build('stand_in_model', attributes).wont_be_nil
        FrozenRecordFactory.build('StandInModel', attributes).wont_be_nil
        FrozenRecordFactory.build(:stand_in_model, attributes).wont_be_nil
        FrozenRecordFactory.build(StandInModel, attributes).wont_be_nil
      end
    end
  end

  describe FrozenRecordProxy do
    before do
      @attributes = { key1: 'value1', key2: true, key3: 1 }

      @record1 = StandInModel.new(@attributes, without_protection: true)
      @record2 = StandInModel.new(@attributes, without_protection: true)

      @noisy_proxy = FrozenRecordProxy.new(@record1, false)
      @quiet_proxy = FrozenRecordProxy.new(@record1, true)
    end

    it "should freeze the record and mark it as readonly" do
      mock_record = MiniTest::Mock.new
      mock_record.expect(:freeze, nil)
      mock_record.expect(:readonly!, nil)
      FrozenRecordProxy.new(mock_record)
      mock_record.verify.must_equal true
    end

    it "should allow read access to its attributes" do
      @attributes.each do |key, value|
        eval("@noisy_proxy.#{key.to_s}").must_equal value
      end
    end

    it "should not allow write access to its attributes" do
      assert_raises RuntimeError do
        @noisy_proxy.key1 = "new value"
      end
    end

    it "should pass through any other method calls" do
      assert_raises NoMethodError do
        @noisy_proxy.blah
      end
    end

    describe "when in silent mode" do
      it "should ignore write access to its attributes" do
        @quiet_proxy.key1 = "new value"
        @quiet_proxy.key1.must_equal "value1"
      end

      it "should pass through any other errors" do
        assert_raises NoMethodError do
          @quiet_proxy.blah
        end
      end
    end
  end
end
