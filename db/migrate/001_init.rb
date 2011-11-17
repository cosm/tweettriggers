class Init < ActiveRecord::Migration
  def self.up
    create_table :users do |t|
      t.column :twitter_name, :string, :null => false
      t.column :oauth_token, :string
      t.column :oauth_secret, :string
    end

    add_index :users, :twitter_name, :unique => true
    
    
    create_table :triggers do |t|
      t.column :hash, :string, :null => false, :limit => 40
      t.column :user_id, :integer, :null => false
      t.column :tweet, :string
    end
    
    add_index :triggers, :hash, :unique => true
    add_index :triggers, :user_id
    
  end

  def self.down
    drop_table :users
    drop_table :triggers
  end
end
