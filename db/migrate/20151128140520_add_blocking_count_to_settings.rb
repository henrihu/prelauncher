class AddBlockingCountToSettings < ActiveRecord::Migration
  def change
    add_column :settings, :blocking_count, :integer, :default => 1
  end
end
