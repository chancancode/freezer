require 'freezer/frozen_record_proxy'
require 'active_record/connection_adapters/column'

module Freezer
  module Serialization
    module HStore
      SERIALIZABLE_TYPES = [
        :primary_key, :string, :text, :integer, :float, :decimal,
        :datetime,:timestamp, :time, :date, :boolean
      ].freeze

      class << self
        # TODO give each version its own module or something
        def serialize(record)
          # Start with the serialization format version string
          hstore = {':sv'=>'1'}

          columns = record.class.columns
          attributes = record.attributes

          columns.each do |column|
            key = serialize_key(column.name, column.type)
            value = serialize_value(column.type, attributes[column.name])
            hstore[key] = value
          end

          hstore
        end

        def deserialize(klass, attributes, silent = false)
          attributes = attributes.dup
          sv = attributes.delete(':sv')
          raise ArgumentError, "Unknown serialization format #{sv.to_s}" unless sv == '1'
          attributes = attributes.inject({}) do |hash,(key,value)|
            real_key, type = deserialize_key(key)
            hash[real_key] = deserialize_value(type, value)
            hash
          end
          FrozenRecordFactory.build(klass, attributes, silent)
        end

        def serialize_key(key, type)
          "#{key.gsub(':','::')}:#{type}"
        end

        def deserialize_key(serialized)
          m = serialized.match(/(.*):([^:]+)\z/)
          [m[1].gsub('::',':'), m[2].to_sym]
        end

        def serialize_value(type, value)
          raise ArgumentError, "Do not know how to serialize #{type.to_s}" unless SERIALIZABLE_TYPES.include? type
          return nil if value.nil?
          value.to_s
        end

        def deserialize_value(type, value)
          raise ArgumentError, "Do not know how to deserialize #{type.to_s}" unless SERIALIZABLE_TYPES.include? type
          return nil if value.nil?
          # For now, we will let AR handle the casting for us
          value.to_s
        end
      end
    end
  end
end