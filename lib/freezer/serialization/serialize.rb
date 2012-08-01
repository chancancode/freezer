require 'freezer/frozen_record_proxy'

module Freezer
  module Serialization
    module Serialize
      class << self
        def serialize(record)
          record.attributes.dup
        end

        def deserialize(klass, attributes, silent = false)
          FrozenRecordFactory.build(klass, attributes.dup, silent)
        end
      end
    end
  end
end