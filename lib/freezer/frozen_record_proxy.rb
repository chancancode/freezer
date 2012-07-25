require 'active_support/core_ext/string/inflections'
require 'active_record/errors'

module Freezer
  module FrozenRecordFactory
    class << self
      def get_class(klass)
        klass.is_a?(Class) ? klass : klass.to_s.camelize.constantize
      end

      def build(klass, attributes, slient = false)
        record = get_class(klass).new attributes, without_protection: true
        FrozenRecordProxy.new(record, slient)
      end
    end
  end

  class FrozenRecordProxy < BasicObject
    [:==, :equal?, :!, :!=, :instance_eval, :instance_exec].each { |meth| undef_method(meth) }

    def initialize(record, silent = false)
      @silent = silent
      @record = record
      @record.readonly!
      @record.freeze
    end

    private

    def method_missing(method, *args, &block)
      begin
        @record.__send__(method, *args, &block)
      rescue ::RuntimeError => e
        @record.__send__(:raise, e) unless @silent && e.message == "can't modify frozen Hash"
      rescue ::ActiveRecord::ReadOnlyRecord => e
        @record.__send__(:raise, e) unless @silent
      end
    end
  end
end