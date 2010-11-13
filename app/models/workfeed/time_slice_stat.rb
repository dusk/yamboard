module Workfeed
  class TimeSliceStat < ActiveRecord::Base

    establish_connection(ActiveRecord::Base.configurations["workfeed"])

    # Workfeed::TimeSliceStat.last_slice.first
    scope :last_slice, :conditions => 'slice_time = (SELECT MAX(slice_time) FROM time_slice_stats)'

    scope :by_slice, lambda{ |slice| { :conditions => {:slice_time => slice}} }

    def sum_fields(fields)
      fields.inject(0) { |value, field| value + self.send(field) }
    end

  end
end
