require 'freezer/active_record_extensions'
require 'active_record/base'

class ActiveRecord::Base
  include Freezer::ActiveRecordExtensions
end