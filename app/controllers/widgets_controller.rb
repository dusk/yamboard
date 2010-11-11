class WidgetsController < ApplicationController

  def index
    @stats_today      = Workfeed::TimeSliceStat.get_stats(1.day.ago, Time.now).first
    @stats_7_days = Workfeed::TimeSliceStat.get_stats(7.days.ago, Time.now)
  end

  def total_active_users
  end

  def total_active_networks
  end

  def new_users_today
  end

  def new_networks_today
  end

end
