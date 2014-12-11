# -*- encoding: utf-8 -*-

module ActiveRecord
  module ConnectionAdapters
    module Hana
      module SchemaStatements

        def returning(value)
          yield(value)
          value
        end

        def structure_dump
          # TODO: Implement
        end

        # === Migrations ======================================= #

        if ::ActiveRecord::VERSION::STRING.to_f >= 3.1
          def assume_migrated_upto_version(version, migrations_paths = ActiveRecord::Migrator.migrations_paths)
            migrations_paths = Array(migrations_paths)
            version = version.to_i
            sm_table = quote_table_name(ActiveRecord::Migrator.schema_migrations_table_name)

            migrated = select_values("SELECT \"version\" FROM #{sm_table}").map { |v| v.to_i }
            paths = migrations_paths.map {|p| "#{p}/[0-9]*_*.rb" }
            versions = Dir[*paths].map do |filename|
              filename.split('/').last.split('_').first.to_i
            end

            unless migrated.include?(version)
              execute "INSERT INTO #{sm_table} (\"version\") VALUES ('#{version}')"
            end

            inserted = Set.new
              (versions - migrated).each do |v|
                if inserted.include?(v)
                  raise "Duplicate migration #{v}. Please renumber your migrations to resolve the conflict."
                elsif v < version
                  execute "INSERT INTO #{sm_table} (\"version\") VALUES ('#{v}')"
                  inserted << v
                end
              end
            end
          end

        # === Tables =========================================== #              

        def table_exists?(table_name)
          return false if table_name.blank?
          
          unquoted_table_name = Utils.unqualify_table_name(table_name)
          super || tables.include?(unquoted_table_name) || views.include?(unquoted_table_name)
        end

        def column_for(table_name, column_name)
          unless column = columns(table_name).find { |c| c.name == column_name.to_s }
            raise "No such column: #{table_name}.#{column_name}"
          end
          column
        end
        
        def tables
          select_values "SELECT LOWER(TABLE_NAME) FROM TABLES WHERE SCHEMA_NAME=\'#{@connection_options[:database].upcase}\'", 'SCHEMA'
        end
        
        def indexes(table_name, name = nil)
          indexes = []
          return indexes if !table_exists?(table_name)
          results = select "SELECT LOWER(TABLE_NAME) AS TABLE_NAME, LOWER(INDEX_NAME) AS INDEX_NAME, LOWER(CONSTRAINT) AS CONSTRAINT FROM INDEXES WHERE SCHEMA_NAME=\'#{@connection_options[:database].upcase}\' AND TABLE_NAME=\'#{table_name.upcase}\'",  'INDEXES'
          results.each do |row|
            indexes << IndexDefinition.new(row["table_name"], row["index_name"], (!row["constraint"].nil? && row["constraint"].include?("UNIQUE")) || row[:CONSTRAINT] == "PRIMARY KEY")
          end
          indexes
        end

        def table_structure(table_name)
          returning structure = select_rows("SELECT LOWER(COLUMN_NAME) AS COLUMN_NAME, DEFAULT_VALUE, DATA_TYPE_NAME, IS_NULLABLE FROM TABLE_COLUMNS WHERE SCHEMA_NAME=\'#{@connection_options[:database].upcase}\' AND TABLE_NAME=\'#{table_name.upcase}\'") do
            raise(ActiveRecord::StatementInvalid, "Could not find table '#{table_name}'") if structure.empty?
          end
        end
                
        def generic_table_definition(adapter = nil, table_name = nil, is_temporary = nil, options = {})
          if ::ActiveRecord::VERSION::MAJOR >= 4
            TableDefinition.new(native_database_types, table_name, is_temporary, options)
          else
            TableDefinition.new(adapter)
          end
        end

        def create_table(table_name, options = {})
          td = generic_table_definition(self, table_name, options[:temporary], options[:options])
          td.primary_key(options[:primary_key] || Base.get_primary_key(table_name.to_s.singularize)) unless options[:id] == false

          yield td if block_given?

          if options[:force] && table_exists?(table_name)
            drop_table(table_name, options)
          end
                    
          create_sequence(default_sequence_name(table_name, nil))
          if ::ActiveRecord::VERSION::MAJOR >= 4
            create_sql = schema_creation.accept td
          else  
            create_sql = "CREATE TABLE "
            create_sql << "#{quote_table_name(table_name)} ("
            create_sql << td.to_sql
            create_sql << ") #{options[:options]}"
          end
                        
          if options[:row]
            create_sql.insert(6," ROW")
          elsif options[:column]
            create_sql.insert(6," COLUMN")
          elsif options[:history]
            create_sql.insert(6," HISTORY COLUMN")
          elsif options[:global_temporary]
            create_sql.insert(6," GLOBAL TEMPORARY")
          elsif options[:local_temporary]
            create_sql.insert(6," GLOBAL LOCAL")
          else
            create_sql.insert(6," #{default_table_type}")
          end

          execute create_sql
          if 1 == select_value("SELECT 1 FROM TABLE_COLUMNS WHERE COLUMN_NAME = \'#{quote_column_name(primary_key(table_name))}\' AND SCHEMA_NAME=\'#{@connection_options[:database].upcase}\' AND TABLE_NAME=\'#{table_name.upcase}\'")
            execute "ALTER SEQUENCE #{quote_table_name(default_sequence_name(table_name, nil))} RESET BY SELECT IFNULL(MAX(#{quote_column_name(primary_key(table_name))}), 0) + 1 FROM #{quote_table_name(table_name)}"
          end

          if ::ActiveRecord::VERSION::MAJOR >= 4
            td.indexes.each_pair { |c,o| add_index table_name, c, o }
          end   
                    
        end

        def rename_table(table_name, new_name)
          execute "RENAME TABLE #{quote_table_name(table_name)} TO #{quote_table_name(new_name)}"
          rename_sequence(table_name, new_name)
        end

        def drop_table(table_name, options = {})
          execute "DROP TABLE #{quote_table_name(table_name)}"
          drop_sequence(default_sequence_name(table_name, nil))
        end

        def default_table_type
          "COLUMN"
        end

        # === Columns ========================================== #

        def columns(table_name, name = nil)
          return [] if table_name.blank?

          table_structure(table_name).map do |column|
            HanaColumn.new column[0], column[1], column[2], column[3]
          end
        end

        def add_column(table_name, column_name, type, options = {})
          add_column_sql = "ALTER TABLE #{quote_table_name(table_name)} ADD ( #{quote_column_name(column_name)} #{type_to_sql(type, options[:limit], options[:precision], options[:scale])}"
          add_column_options!(add_column_sql, options)
          add_column_sql << ")"
          execute(add_column_sql)
        end

        def change_column(table_name, column_name, type, options = {})
          change_column_sql =  "ALTER TABLE #{quote_table_name(table_name)} ALTER (#{quote_column_name(column_name)} #{type_to_sql(type, options[:limit], options[:precision], options[:scale])}"
          add_column_options!(change_column_sql, options)
          change_column_sql << ")"
          execute(change_column_sql)
        end

        def change_column_default(table_name, column_name, default)
          column = column_for(table_name, column_name)
          change_column table_name, column_name, column.sql_type, :default => default
        end
        
        def change_column_null(table_name, column_name, null)
          column = column_for(table_name, column_name)
          change_column table_name, column_name, column.sql_type, :null => null
        end

        def rename_column(table_name, column_name, new_column_name)
          execute "RENAME COLUMN #{quote_table_name(table_name)}.#{quote_column_name(column_name)} TO #{quote_column_name(new_column_name)}"
        end

        def remove_column(table_name, *column_names)
          if column_names.flatten!
            message = 'Passing array to remove_columns is deprecated, please use ' +
                      'multiple arguments, like: `remove_columns(:posts, :foo, :bar)`'
            ActiveSupport::Deprecation.warn message, caller
          end

          columns_for_remove(table_name, *column_names).each do |column_name|
            execute "ALTER TABLE #{quote_table_name(table_name)} DROP PRIMARY KEY" if quote_column_name(primary_key(table_name)) == column_name
            execute "ALTER TABLE #{quote_table_name(table_name)} DROP (#{column_name})"
          end
        end
        
        alias :remove_columns :remove_column

        def remove_default_constraint(table_name, column_name)
          execute "ALTER TABLE #{quote_table_name(table_name)} DROP CONSTRAINT #{default_constraint_name(table_name, column_name)}"
        end

        # === Views ============================================ #
                
        def views
          select_values "SELECT VIEW_NAME FROM VIEWS WHERE SCHEMA_NAME=\'@connection_options[:database].upcase}\'", 'SCHEMA'
        end

        # === Sequences ======================================== #

        def create_sequence(sequence, options = {})
          create_sql = "CREATE SEQUENCE #{quote_table_name(sequence)} INCREMENT BY 1 START WITH 1 NO CYCLE"
          execute create_sql                
        end

        def rename_sequence(table_name, new_name)
          seq = quote_table_name(default_sequence_name(new_name, nil))
          rename_sql =  "CREATE SEQUENCE #{seq} "
          rename_sql << "INCREMENT BY 1 "
          rename_sql << "START WITH #{next_sequence_value(default_sequence_name(table_name, nil))} NO CYCLE "
          rename_sql << "RESET BY SELECT IFNULL(MAX(#{quote_column_name('id')}), 0) + 1 FROM #{quote_table_name(new_name)}"
          execute rename_sql

          drop_sequence(default_sequence_name(table_name, nil))
        end

        def drop_sequence(sequence)
          execute "DROP SEQUENCE #{quote_table_name(sequence)}"     
        end

        # === Datatypes ======================================== #
                
        def native_database_types
          @native_database_types ||= initialize_hana_database_types.freeze
        end
                
        def initialize_hana_database_types
          {
            # Standard Rails Data Types
            :primary_key  => "BIGINT NOT NULL PRIMARY KEY",
            :string       => { :name => "NVARCHAR", :limit => 255  },
            :text         => { :name => "NCLOB" },
            :integer      => { :name => "INTEGER" },
            :float        => { :name => "FLOAT"},
            :decimal      => { :name => "DECIMAL" },
            :datetime     => { :name => "TIMESTAMP" },
            :timestamp    => { :name => "TIMESTAMP" },
            :time         => { :name => "TIME" },
            :date         => { :name => "DATE" },
            :binary       => { :name => "BLOB" },
            :boolean      => { :name => "TINYINT"},

            #Additional Hana Data Types
            :bigint       => { :name => "BIGINT" },
          }
        end

        # Maps logical Rails types to HANA-specific data types.
        def type_to_sql(type, limit = nil, precision = nil, scale = nil)
          case type.to_s
            when 'decimal'
              if precision > 38
                precision = 38
              end
              super
            
            when 'integer'
              return 'integer' unless limit

              case limit
                when 1; 'tinyint'
                when 2; 'smallint'
                when 3, 4; 'integer'
                when 5..8; 'bigint'
                else raise(ActiveRecordError, "No integer type has byte size #{limit}. Use a numeric with precision 0 instead.")
              end
              
              when 'text', 'binary'
                limit = nil
                super
            else
              super
          end
        end
    
        # === Indexes ========================================= #

        def remove_index!(table_name, index_name)
          execute "DROP INDEX #{quote_column_name(index_name)}"
        end     

        def rename_index(table_name, old_name, new_name)
          execute "RENAME INDEX #{quote_column_name(old_name)} TO #{quote_column_name(new_name)}"
        end             

        # === Schemas ========================================= #
        
        def schemas
          select_values "SELECT LOWER(SCHEMA_NAME) FROM SCHEMAS"
        end

        def create_schema(name)
          execute "CREATE SCHEMA #{quote_schema_name(name)}"
        end

        def set_schema(name)
          execute "SET SCHEMA #{quote_schema_name(name)}"
        end

        def drop_schema(name)
          execute "DROP SCHEMA #{quote_schema_name(name)} CASCADE"
        end
                
        # === Utils ====================================== #
        def quote_schema_name(name)
          quote_column_name(name)
        end
        def quote_column_name(name)
          %("#{name.to_s.upcase.gsub('"', '""')}")
        end

      end
    end
  end
end
