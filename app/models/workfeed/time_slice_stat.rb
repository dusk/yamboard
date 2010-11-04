module Workfeed
  class TimeSliceStat < ActiveRecord::Base
    establish_connection(ActiveRecord::Base.configurations["workfeed"])
    
    class << self
      def get_stats(start_time, end_time)
        where([%{
          slice_time >= ? 
          AND slice_time < ? 
          AND EXTRACT('hour' FROM slice_time) = 0 
          AND EXTRACT('minute' FROM slice_time) = 0
        }.squish, start_time.beginning_of_day, end_time.beginning_of_day]).all
      end
    end
  end
end