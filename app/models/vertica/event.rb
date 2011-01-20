module Vertica
  class Event < Vertica::Base
    set_table_name 'fact_events'
  end
end