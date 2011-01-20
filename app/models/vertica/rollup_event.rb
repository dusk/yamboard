# Vertica::RollupEvent.where(:period_id => 1).where(:event_name => 'user_activation').all
module Vertica
  class RollupEvent < Vertica::Base
    set_table_name 'rollup_events'
  end
end