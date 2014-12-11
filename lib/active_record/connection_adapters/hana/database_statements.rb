# -*- encoding: utf-8 -*-

module ActiveRecord
  module ConnectionAdapters
    module Hana
      module DatabaseStatements
        
        # === Selecting ============================ #  

        def select_rows(sql, name = nil, binds = [])
          exec_query(sql, name, binds).rows
        end 

        def select(sql, name = nil, binds = [])
        if ::ActiveRecord::VERSION::MAJOR >= 4
          exec_query(sql, name, binds)
        else
          exec_query(sql, name, binds).to_a
          end
        end

        # === Inserting ============================ #

        def insert(arel, name = nil, pk = nil, id_value = nil, sequence_name = nil, binds = []) 
          sql, binds = sql_for_insert(to_sql(arel, binds), pk, id_value, sequence_name, binds)          
          exec_insert(sql, name, binds)
          value = id_value || (last_inserted_id(sequence_name) if sequence_name)      
        end 

        def empty_insert_statement_value
          "null"
        end
        
        def current_database
          @connection_options[:database]
        end 
        
        def insert_fixture(fixture, table_name)
          columns = schema_cache.columns_hash(table_name)
          key_list   = []
          value_list = []
          fixture.map do |name, value|
            key_list << quote_column_name(name)
            value_list << type_cast(value, columns[name])
          end
          prep = Array.new( key_list.size, "?").join(',')
          args = ["INSERT INTO #{quote_table_name(table_name)} (#{key_list.join(', ')}) VALUES (#{prep})"]
          args= args.concat(value_list)
          begin
            stmt = @connection.run(*args)
          ensure
            stmt.drop if !stmt.nil?
          end
          if 1 == select_value("SELECT 1 FROM TABLE_COLUMNS WHERE COLUMN_NAME = 'id' AND SCHEMA_NAME=\'#{@connection_options[:database]}\' AND TABLE_NAME=\'#{table_name}\'") 
            val = select_value "SELECT IFNULL(MAX(#{quote_column_name('id')}), 0) + 1 FROM #{quote_table_name(table_name)}"
            execute "ALTER SEQUENCE #{quote_table_name(default_sequence_name(table_name, nil))} RESTART WITH #{val}"
          end
        end

        # === Executing ============================ #

        def exec_query(sql, name = nil, binds = [])
          log(sql, name, binds) do
            begin
              # Don't cache statements without bind values
              if binds.empty?
                stmt = @connection.run(sql)
                cols = stmt.columns(true).map { |c| c.name.downcase }
                records = stmt.fetch_all || []
              else
                # without statement caching
                args = bind_params(sql,binds)
                stmt = @connection.run(*args)
                cols = stmt.columns(true).map { |c| c.name.downcase }
                records = stmt.fetch_all || []
              end
            ensure
              stmt.drop if !stmt.nil?
            end
            ActiveRecord::Result.new(cols, records)
          end
        end

        def execute(sql, name = nil) #:nodoc:
          log(sql, name) do
            stmt = @connection.run(sql)
            stmt.drop
          end
        end
      
        # === Binds =============================== #

        def bind_params(sql, binds = [])
          args = [sql]              
          binds.each do |bind|
            args << type_cast(bind[1], bind[0])
          end
          args
        end
        
        # === Sequence ============================ #
  
        def default_sequence_name(table, column)
          "#{table}_seq"
        end       
          
        def next_sequence_value(sequence)
          uncached do
            select_value("SELECT #{quote_table_name(sequence)}.NEXTVAL FROM DUMMY")
          end       
        end
        
        def last_insert_id(sequence)
          uncached do
            select_value("SELECT #{quote_table_name(sequence)}.CURRVAL FROM DUMMY")
          end
        end
        
        # === Transaction Management ============== #
        
        def commit_db_transaction
        # COMMIT command only works with 'autocommit' disabled session.
          execute "COMMIT"
        end

        def lock_table(table)
          execute  "LOCK TABLE #{quote_table_name(table)} IN EXCLUSIVE MODE"
        end

        def rollback_db_transaction
        # ROLLBACK command only works with an autocommit disabled session.
          execute "ROLLBACK"
        end

        def valid_isolation_levels
          ["READ COMMITTED", "REPEATABLE READ", "SERIALIZABLE"]
        end

        def set_isolation_level(isolation_level)
          raise ArgumentError, "Invalid isolation level, #{isolation_level}. Supported levels include #{valid_isolation_levels.to_sentence}." if !valid_isolation_levels.include?(isolation_level.upcase)
          execute "SET TRANSACTION ISOLATION LEVEL #{isolation_level}"
        end

        def set_access_mode(access_mode)
          execute "SET TRANSACTION #{access_mode}"
        end

        def begin_db_transaction
        # Any command that changes the database (basically, any SQL command other than SELECT) 
        # will automatically start a transaction if one is not already in effect.
        end

        def outside_transaction?
          nil
        end

        # === Explain ============================= #

        def explain(arel, binds = [])
          sql = "EXPLAIN PLAN FOR #{to_sql(arel, binds)}"
          ExplainPrettyPrinter.new.pp(exec_query(sql, 'EXPLAIN', binds))
        end 
        
        class ExplainPrettyPrinter
        # Pretty prints the result of a EXPLAIN QUERY PLAN
          def pp(result) # :nodoc:
            result.rows.map do |row|
              row.join('|')
            end.join("\n") + "\n"
          end
        end

      end
    end
  end
end
