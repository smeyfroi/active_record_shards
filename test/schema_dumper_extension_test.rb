# frozen_string_literal: true
require File.expand_path('../helper', __FILE__)

if ActiveRecord::VERSION::MAJOR >= 4
  describe ActiveRecordShards::SchemaDumperExtension do
    describe "schema dump" do
      let(:schema_file) { Tempfile.new('active_record_shards_schema.rb') }
      before do
        Phenix.rise!(with_schema: true)

        # create shard-specific columns
        ActiveRecord::Migrator.migrations_paths = [File.join(File.dirname(__FILE__), "/migrations")]
        ActiveRecord::Migrator.migrate(ActiveRecord::Migrator.migrations_paths)
      end

      after do
        schema_file.unlink
        Phenix.burn!
      end

      it "includes the sharded tables" do
        ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, schema_file)
        schema_file.close

        Phenix.rise! # Recreate the database without loading the schema
        load(schema_file)

        ActiveRecord::Base.on_all_shards do
          assert ActiveRecord::Base.connection.public_send(connection_exist_method, :schema_migrations), "Schema Migrations doesn't exist"
          assert ActiveRecord::Base.connection.public_send(connection_exist_method, :accounts)
          assert ActiveRecord::Base.connection.select_value("select version from schema_migrations where version = '20110824010216'")
          assert ActiveRecord::Base.connection.select_value("select version from schema_migrations where version = '20110829215912'")
        end

        ActiveRecord::Base.on_all_shards do
          assert table_has_column?("emails", "sharded_column")
          assert !table_has_column?("accounts", "non_sharded_column")
        end

        ActiveRecord::Base.on_shard(nil) do
          assert !table_has_column?("emails", "sharded_column")
          assert table_has_column?("accounts", "non_sharded_column")
        end
      end
    end
  end
end
