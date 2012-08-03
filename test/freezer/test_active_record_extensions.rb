require 'minitest_helper'
require 'freezer/active_record_extensions'

class Address < StandInModel
  @columns = [
    Column.new('customer_id', :primary_key),
    Column.new('line1', :string),
    Column.new('line2', :string),
    Column.new('city', :string),
    Column.new('state', :string),
    Column.new('country', :string),
    Column.new('zip', :integer)
  ].freeze
end

class Product < StandInModel
  @columns = [
    Column.new('merchant_id', :primary_key),
    Column.new('name', :string),
    Column.new('description', :text),
    Column.new('price', :decimal)
  ].freeze
end

class Order < StandInModel
  @columns = [
    Column.new('line_item', :hstore),
    Column.new('frozen_billing_address', :text),
    Column.new('frozen_shipping_address', :hstore)
  ].freeze

  include Freezer::ActiveRecordExtensions

  has_one_frozen :product, column_name: 'line_item'
  has_one_frozen :billing_address, class_name: Address
  has_one_frozen :shipping_address, class_name: 'Address', slient: true
end

describe Order do
  before do
    @billing_address = Address.new({
      customer_id: 1,
      line1: '123 Union Street',
      line2: nil,
      city: 'San Francisco',
      state: 'CA',
      country: 'US',
      zip: 90001
    }, without_protection: true)

    @serialized_billing_address = {
      "customer_id" => 1,
      "line1" => "123 Union Street",
      "line2" => nil,
      "city" => "San Francisco",
      "state" => "CA",
      "country" => "US",
      "zip" => 90001
    }

    @shipping_address = Address.new({
      customer_id: nil,
      line1: '456 Whatever Ave',
      line2: '',
      city: 'Seattle',
      state: 'WA',
      country: 'US',
      zip: 90002
    }, without_protection: true)

    @serialized_shipping_address = {
      ':sv' => '1',
      'customer_id:primary_key' => nil,
      'line1:string' => '456 Whatever Ave',
      'line2:string' => '',
      'city:string' => 'Seattle',
      'state:string' => 'WA',
      'country:string' => 'US',
      'zip:integer' => '90002'
    }

    @product = Product.new({
      merchant_id: 999,
      name: 'Settlers of Catan',
      price: 33.41,
      description: <<-EOD
        The Settlers of Catan is a multiplayer board game designed by 
        Klaus Teuber and first published in 1995 in Germany by 
        Franckh-Kosmos Verlag (Kosmos) as Die Siedler von Catan.

        Players assume the roles of settlers, each attempting to build 
        and develop holdings while trading and acquiring resources. 
        Players are rewarded points as their settlements grow; the 
        first to reach a set number of points is the winner. At no 
        point in the game is any player eliminated.
      EOD
    }, without_protection: true)

    @serialized_product = {
      ':sv' => '1',
      'merchant_id:primary_key' => '999',
      'name:string' => 'Settlers of Catan',
      'price:decimal' => '33.41',
      'description:text' => <<-EOD
        The Settlers of Catan is a multiplayer board game designed by 
        Klaus Teuber and first published in 1995 in Germany by 
        Franckh-Kosmos Verlag (Kosmos) as Die Siedler von Catan.

        Players assume the roles of settlers, each attempting to build 
        and develop holdings while trading and acquiring resources. 
        Players are rewarded points as their settlements grow; the 
        first to reach a set number of points is the winner. At no 
        point in the game is any player eliminated.
      EOD
    }
  end

  describe "when loaded with previously frozen associations" do
    before do
      @order = Order.new({
        line_item: @serialized_product,
        frozen_billing_address: @serialized_billing_address,
        frozen_shipping_address: @serialized_shipping_address
      }, without_protection: true)
    end

    it "should return a frozen copy of the association from its readers" do
      @order.product.frozen?.must_equal true
      @order.shipping_address.frozen?.must_equal true
      @order.billing_address.frozen?.must_equal true
    end

    it "should return a readonly copy of the association from its readers" do
      @order.product.readonly?.must_equal true
      @order.shipping_address.readonly?.must_equal true
      @order.billing_address.readonly?.must_equal true
    end

    it "should not allow further changes on the frozen copy" do
      assert_raises RuntimeError do
        @order.product.name = "bogus"
      end
    end

    it "should reconstruct the frozen record" do
      [[@product, :product],[@shipping_address, :shipping_address],[@billing_address, :billing_address]].each do |ivar, sym|
        ivar.attributes.each do |(key, value)|
          if value.nil?
            @order.__send__(sym).__send__(key).must_be_nil
          else
            # TODO these should not be in strings.
            @order.__send__(sym).__send__(key).to_s.must_equal value.to_s
          end
        end
      end
    end

    it "should allow overwriting the frozen record" do
      @order.shipping_address = nil
      @order.shipping_address.must_be_nil
      @order.frozen_shipping_address.must_be_nil

      @order.shipping_address = @billing_address
      @order.shipping_address.line1.must_equal @billing_address.line1
      @order.frozen_shipping_address.must_be_kind_of Hash
    end

    it "should not allow freezing records of the wrong class" do
      assert_raises ArgumentError do
        @order.product = @shipping_address
      end
    end
  end

  describe "when loaded without previously frozen associations" do
    before do
      @order = Order.new({
        line_item: nil,
        frozen_billing_address: nil,
        frozen_shipping_address: nil
      }, without_protection: true)
    end

    it "should return nil when asking for the frozen associations" do
      @order.product.must_be_nil
      @order.shipping_address.must_be_nil
      @order.billing_address.must_be_nil
    end

    describe "when freezing associations" do
      before do
        @order.product = @product
        @order.shipping_address = @shipping_address
        @order.billing_address = @billing_address
      end

      it "should serialize the association into column_name" do
        @order.line_item.must_equal @serialized_product
        @order.frozen_billing_address.must_equal @serialized_billing_address
        @order.frozen_shipping_address.must_equal @serialized_shipping_address
      end

      it "should freeze the association" do
        [[@product, :product],[@shipping_address, :shipping_address],[@billing_address, :billing_address]].each do |ivar, sym|
          ivar.attributes.each do |(key, value)|
            if value.nil?
              @order.__send__(sym).__send__(key).must_be_nil
            else
              # TODO these should not be in strings.
              @order.__send__(sym).__send__(key).to_s.must_equal value.to_s
            end
          end
        end
      end

      it "should return a frozen copy of the association from its readers" do
        @order.product.frozen?.must_equal true
        @order.shipping_address.frozen?.must_equal true
        @order.billing_address.frozen?.must_equal true
      end

      it "should return a readonly copy of the association from its readers" do
        @order.product.readonly?.must_equal true
        @order.shipping_address.readonly?.must_equal true
        @order.billing_address.readonly?.must_equal true
      end

      it "should not freeze the assignee" do
        @product.frozen?.must_equal false
        @shipping_address.frozen?.must_equal false
        @billing_address.frozen?.must_equal false
      end

      it "should not mark the assignee as readonly" do
        @product.readonly?.must_equal false
        @shipping_address.readonly?.must_equal false
        @billing_address.readonly?.must_equal false
      end

      it "should not allow further changes on the frozen copy" do
        assert_raises RuntimeError do
          @order.product.name = "bogus"
        end
      end

      it "should not pick up new changes in the assignee once its been frozen" do
        @product.name = "bogus"
        @order.product.name.must_equal "Settlers of Catan"
      end

      it "should allow overwriting the frozen record" do
        @order.shipping_address = nil
        @order.shipping_address.must_be_nil
        @order.frozen_shipping_address.must_be_nil

        @order.shipping_address = @billing_address
        @order.shipping_address.line1.must_equal @billing_address.line1
        @order.frozen_shipping_address.must_be_kind_of Hash
      end

      it "should not allow freezing records of the wrong class" do
        assert_raises ArgumentError do
          @order.product = @shipping_address
        end
      end
    end
  end
end
