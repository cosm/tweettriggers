class AddMissingColumnsToTriggers < ActiveRecord::Migration
  def self.up
    add_column :triggers, :pachube_feed_id, :integer
    add_column :triggers, :pachube_stream_id, :string
    add_column :triggers, :trigger_type, :string
    add_column :triggers, :threshold_value, :string
  end

  def self.down
    remove_column :triggers, :pachube_feed_id
    remove_column :triggers, :pachube_stream_id
    remove_column :triggers, :trigger_type
    remove_column :triggers, :threshold_value
  end
end
