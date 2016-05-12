# frozen_string_literal: true
require File.expand_path('../helper', __FILE__)

# ActiveRecordShards overrides some of the ActiveRecord tasks, so
# ActiveRecord needs to be loaded first.
Rake::Application.new.rake_require("active_record/railties/databases")
require 'active_record_shards/tasks'

describe "Database rake tasks" do
  let(:config) { Phenix.load_database_config('test/database_tasks.yml') }
  let(:master_name) { config['test']['database'] }
  let(:slave_name) { config['test']['slave']['database'] }
  let(:shard_names) { config['test']['shards'].values.map { |v| v['database'] } }
  let(:database_names) { shard_names + [master_name, slave_name] }

  before do
    if ActiveRecord::VERSION::MAJOR >= 4
      ActiveRecord::Tasks::DatabaseTasks.database_configuration = config
      ActiveRecord::Tasks::DatabaseTasks.env = RAILS_ENV
      ActiveRecord::Tasks::DatabaseTasks.migrations_paths = '/'
    else
      # It uses Rails.application.config to config ActiveRecord
      Rake::Task['db:load_config'].clear
      ActiveRecord::Base.configurations = config
    end
  end

  after do
    Phenix.burn!
  end

  describe "db:create" do
    it "creates the database and all shards" do
      rake('db:create')
      databases = show_databases(config)

      assert_includes databases, master_name
      refute_includes databases, slave_name
      shard_names.each do |name|
        assert_includes databases, name
      end
    end
  end

  describe "db:drop" do
    it "drops the database and all shards" do
      rake('db:create')
      rake('db:drop')
      databases = show_databases(config)

      refute_includes databases, master_name
      shard_names.each do |name|
        refute_includes databases, name
      end
    end
  end
end
