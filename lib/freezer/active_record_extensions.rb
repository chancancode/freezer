require 'active_support/concern'
require 'active_support/core_ext/hash/reverse_merge'
require 'active_support/core_ext/string/inflections'

module Freezer
  module ActiveRecordExtensions
    extend ActiveSupport::Concern

    module ClassMethods
      def has_one_frozen(association_name, options = {})
        options.reverse_merge!({
          class_name: association_name.to_s,
          column_name: "frozen_#{association_name.to_s}",
          slient: false
        })

        klass = options[:class_name].camelize.constantize
        accessor_name = association_name.to_s.underscore
        serializer = if self.columns_hash[options[:column_name].to_s].type == :hstore
          require 'freezer/serialization/hstore'
          ::Freezer::Serialization::HStore
        else
          require 'freezer/serialization/serialize'
          self.serialize options[:column_name].to_sym, Hash
          ::Freezer::Serialization::Serialize
        end

        # Reader
        define_method(accessor_name) do
          @freezer_cache ||= {}

          if @freezer_cache.key? accessor_name
            return @freezer_cache[accessor_name]
          end

          # On cache miss, try to read from the raw accessor
          if hstore = read_attribute(options[:column_name])
            @freezer_cache[accessor_name] = serializer.deserialize(options[:class_name], hstore, options[:slient])
          else
            @freezer_cache[accessor_name] = nil
          end

          @freezer_cache[accessor_name]
        end

        # Writer
        define_method("#{accessor_name}=") do |record|
          unless record.nil? || record.is_a?(klass)
            message = "#{klass}(##{klass.object_id}) expected, got #{record.class}(##{record.class.object_id})"
            raise ArgumentError, message
          end

          @freezer_cache ||= {}

          if record
            write_attribute(options[:column_name], serializer.serialize(record))
          else
            write_attribute(options[:column_name], nil)
          end

          @freezer_cache.delete(accessor_name)

          # Return the frozen copy of record by calling the reader
          self.__send__(accessor_name.to_sym)
        end
      end
    end
  end
end