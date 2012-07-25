Column = Struct.new(:name, :type)

class StandInModel
  attr_reader :attributes

  class << self
    attr_reader :columns
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
