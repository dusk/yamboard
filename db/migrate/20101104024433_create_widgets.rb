class CreateWidgets < ActiveRecord::Migration

  def self.up
    create_table :widgets do |t|
      t.string  :name
      t.string  :size
      t.string  :db
      t.string  :command
      t.string  :type

      t.timestamps
    end
  end

  def self.down
    drop_table :widgets
  end

end
