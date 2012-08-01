require 'minitest_helper'
require 'freezer/serialization/hstore'

module Freezer
  describe Serialization do
    before do
      @lorem = <<-EOT
        Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor 
        incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud 
        exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute 
        irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla 
        pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia
        deserunt mollit anim id est laborum.
      EOT
    end

    describe ".serialize_key" do
      it "should join the key and type with a colon" do
        Serialization.serialize_key('key', 'type').must_equal 'key:type'
        Serialization.serialize_key('greetings', 'string').must_equal 'greetings:string'
      end

      it "should understand symbols as types" do
        Serialization.serialize_key('key', :type).must_equal 'key:type'
        Serialization.serialize_key('greetings', :string).must_equal 'greetings:string'
      end

      it "should escape colons in key" do
        Serialization.serialize_key('a:b:c', :t).must_equal 'a::b::c:t'
        Serialization.serialize_key('a::b::c', :t).must_equal 'a::::b::::c:t'
        Serialization.serialize_key('a:b:c:', :t).must_equal 'a::b::c:::t'
        Serialization.serialize_key(':', :t).must_equal ':::t'
      end
    end

    describe ".deserialize_key" do
      it "should return the key and type in an array" do
        Serialization.deserialize_key('key:type').must_equal ['key', :type]
        Serialization.deserialize_key('greetings:string').must_equal ['greetings', :string]
      end

      it "should unescape colons in key" do
        Serialization.deserialize_key('a::b::c:t').must_equal ['a:b:c', :t]
        Serialization.deserialize_key('a::::b::::c:t').must_equal ['a::b::c', :t]
        Serialization.deserialize_key('a::b::c:::t').must_equal ['a:b:c:', :t]
        Serialization.deserialize_key(':::t').must_equal [':', :t]
      end
    end

    describe ".serialize_value" do
      it "should know how to serialize standard types" do
        Serialization.serialize_value(:string, 'Hello World').must_equal 'Hello World'
        Serialization.serialize_value(:string, '').must_equal ''
        Serialization.serialize_value(:text, @lorem).must_equal @lorem

        Serialization.serialize_value(:primary_key, 1).must_equal '1'
        Serialization.serialize_value(:integer, 1).must_equal '1'
        Serialization.serialize_value(:integer, -1).must_equal '-1'
        Serialization.serialize_value(:float, 1.5).must_equal '1.5'
        Serialization.serialize_value(:float, -1.5).must_equal '-1.5'
        Serialization.serialize_value(:decimal, 1.5).must_equal '1.5'
        Serialization.serialize_value(:decimal, -1.5).must_equal '-1.5'

        Serialization.serialize_value(:boolean, true).must_equal 'true'
        Serialization.serialize_value(:boolean, false).must_equal 'false'

        # TODO: test :datetime, :timestamp, :time, :date
      end

      it "should not attempt to serialize nil" do
        Serialization::SERIALIZABLE_TYPES.each do |type|
          Serialization.serialize_value(type, nil).must_be_nil
        end
      end

      it "should throw an error when passed a non-serializable type" do
        assert_raises ArgumentError do
          Serialization.serialize_value(:bogus, nil)
        end
      end
    end

    describe ".deserialize_value" do
      # There aren't much to test as this is pretty much an identity function for now

      it "should not attempt to deserialize nil" do
        Serialization.deserialize_value(:string, nil).must_be_nil
      end

      it "should throw an error when passed a non-serializable type" do
        assert_raises ArgumentError do
          Serialization.deserialize_value(:bogus, nil)
        end
      end
    end

    describe "to/from hstore" do
      before do
        class Post < StandInModel
          @columns = [
            Column.new('title', :string),
            Column.new('body', :text),
            Column.new('votes_count', :integer),
            Column.new('author_id', :primary_key),
            Column.new('editor_id', :primary_key),
            Column.new('hidden', :boolean)
          ]
        end

        @record = Post.new({
          title: 'Hello World!',
          body: @lorem,
          votes_count: 15,
          author_id: 1,
          editor_id: nil,
          hidden: false
        }, without_protection: true)

        @serialized = {
          ':sv' => '1',
          'title:string' => 'Hello World!',
          'body:text' => @lorem,
          'votes_count:integer' => '15',
          'author_id:primary_key' => '1',
          'editor_id:primary_key' => nil,
          'hidden:boolean' => 'false'
        }
      end

      describe ".serialize" do
        it "should serialize record to hstore hash" do
          Serialization.serialize(@record).must_equal @serialized
        end
      end

      describe ".deserialize" do
        it "should raise an error for unknown serialization format" do
          @serialized[':sv'] = 'bogus'
          assert_raises ArgumentError do
            Serialization.deserialize :stand_in_model, @serialized
          end
        end

        it "should deserialize hstore hash to a frozen record" do
          deserialized = Serialization.deserialize :stand_in_model, @serialized

          # TODO these shouldn't be strings...
          deserialized.title.must_equal 'Hello World!'
          deserialized.body.must_equal @lorem
          deserialized.votes_count.must_equal '15'
          deserialized.author_id.must_equal '1'
          deserialized.editor_id.must_be_nil
          deserialized.hidden.must_equal 'false'
        end
      end
    end
  end
end
