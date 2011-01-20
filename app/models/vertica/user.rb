module Vertica
  class User < Vertica::Base
    set_table_name 'dimension_users'
  end
end