module Workfeed
  class TimeSliceStat < ActiveRecord::Base
    establish_connection(ActiveRecord::Base.configurations["workfeed"])
    
    class << self
      
      #
      # To get the past week
      # Workfeed::TimeSliceStat.get_stats(8.days.ago, Time.now)
      #
      def get_stats(start_time, end_time)
        where([%{
          slice_time >= ? 
          AND slice_time < ? 
          AND EXTRACT('hour' FROM slice_time) = 7
          AND EXTRACT('minute' FROM slice_time) = 0
        }.squish, start_time.beginning_of_day, end_time.beginning_of_day]).all
      end
    end
  end
end