module Vertica
  class Base < ActiveRecord::Base
    establish_connection(:verthouse)
  end
end