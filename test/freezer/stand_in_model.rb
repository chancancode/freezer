Column = Struct.new(:name, :type)

class StandInModel
  attr_reader :attributes

  class << self
    attr_reader :columns

    def columns_hash
      @columns_hash ||= columns.inject({}) { |hash, column| hash[column.name] = column; hash }
    end

    def serialize(attr_name, type = BasicObject)
      @serialized_attributes ||= {}
      @serialized_attributes[attr_name.to_s] = type
    end

    def serialized_attributes
      @serialized_attributes ||= {}
    end
  end

  def initialize(attributes, options)
    unless options && options[:without_protection]
      raise "without_protection must be set to true"
    end

    # Poor man's HashWithIndifferentAccess
    @attributes = attributes.inject({}){|h,(k,v)|h[k.to_s]=v;h}
  end

  def freeze
    @attributes.freeze
  end

  alias_method :readonly!, :freeze

  def frozen?
    @attributes.frozen?
  end

  alias_method :readonly?, :frozen?

  def read_attribute(attribute)
    @attributes[attribute.to_s]
  end

  def write_attribute(attribute, value)
    if value && type = self.class.serialized_attributes[attribute.to_s]
      raise ArgumentError, "Expecting #{type.inspect} but got #{value.class.inspect}." unless type === value

      # Make sure it can be serialized
      require 'yaml'
      YAML.dump(value)
    end

    @attributes[attribute.to_s] = value
  end

  private

  def method_missing(meth, *args, &block)
    key = meth.to_s
    write = false

    if key.end_with? '='
      key = key[0...-1]
      write = true
    end

    if @attributes.key? key
      if write
        write_attribute(key, args.first)
      else
        read_attribute(key)
      end
    else
      super
    end
  end
end
