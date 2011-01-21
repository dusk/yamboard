module WidgetsHelper

  def vertica_stats(command)
    Vertica::RollupEvent.where(:period_id => 1).where(:application => "web-prod").where(:event_name => command).order(:time_id).last(7)
  end

end
