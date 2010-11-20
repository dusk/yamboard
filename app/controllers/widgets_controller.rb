class WidgetsController < ApplicationController

  def index
    @stats_today      = Workfeed::TimeSliceStat.get_stats(1.day.ago, Time.now).first
    @stats_7_days = Workfeed::TimeSliceStat.get_stats(7.days.ago, Time.now)

    @stats_7_days_networks_active = []
    @stats_7_days.each do |stat|
      @stats_7_days_networks_active << stat.networks
    end

    @stats_7_days_meta_users_active = []
    @stats_7_days.each do |stat|
      @stats_7_days_meta_users_active << stat.updates + stat.replies
    end
  end

  def summary
    get_stats
  end

  def total_active_users
  end

  def total_active_networks
  end

  def new_users_today
  end

  def new_networks_today
  end

  private

  def get_stats

    @stats_today  = Workfeed::TimeSliceStat.last_slice.first
    tss   = Workfeed::TimeSliceStat.last_slice.first
    stats = [tss]
    6.times do |i|
      t = Workfeed::TimeSliceStat.by_slice(tss.slice_time - i.days).first
      stats.unshift(t)
    end

    # to do, make this json

    @stats_7_days = stats

    @slice_times = stats.map{|s| s.slice_time}
    [{'name' => 'Meta users',  'fields' => 'meta_users_active'},
     {'name' => 'Memberships', 'fields' => ['active_invited_users','active_organic_users']},
     {'name' => 'Invitations', 'fields' => 'invitations'},
     {'name' => 'Logins',      'fields' => ['canonical_daily_logins', 'community_daily_logins']},
     {'name' => 'Messages',    'fields' => ['canonical_group_messages_public','canonical_group_messages_private', 'canonical_non_group_messages', 'community_group_messages_public','community_group_messages_private', 'community_non_group_messages']},
     {'name' => 'Canonicals',  'fields' => 'canonical_networks_active'},
     {'name' => 'Communities', 'fields' => 'community_networks_active'},
     {'name' => 'Revenue',     'fields' => 'revenue', 'money' => true}
    ].map do |h|
        h.merge!('data' => stats.map{|stat| stat ? h['fields'].to_a.sum{|f| stat.send(f).nil? ? 0 : stat.send(f)} : 0 })
    end
  end

end
