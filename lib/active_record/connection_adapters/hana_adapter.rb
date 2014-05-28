# -*- encoding: utf-8 -*-

require 'odbc_utf8'

require 'arel/visitors/hana'
require 'arel/core_ext/select_manager'

require 'active_record/connection_adapters/abstract_adapter'
require 'active_record/connection_adapters/hana/database_limits'
require 'active_record/connection_adapters/hana/database_statements'
require 'active_record/connection_adapters/hana/quoting'
require 'active_record/connection_adapters/hana/schema_cache'
require 'active_record/connection_adapters/hana/schema_statements'
require 'active_record/connection_adapters/hana/utils'

require 'active_record/connection_adapters/hana/core_ext/relation/finder_methods'

module ActiveRecord
  class Base
    def self.hana_connection(config)
      config = config.symbolize_keys

      fail ArgumentError, 'Missing :dsn configuration.' unless config.key?(:dsn)
      fail ArgumentError, 'Missing :username configuration.' unless config.key?(:username)
      fail ArgumentError, 'Missing :password configuration.' unless config.key?(:password)
      fail ArgumentError, 'Missing :database configuration.' unless config.key?(:database)

      ConnectionAdapters::HanaAdapter.new(nil, logger, nil, config)
    end
  end

  module ConnectionAdapters
    class HanaColumn < Column
    end # class HanaColumn

    class HanaAdapter < AbstractAdapter
      include Hana::DatabaseStatements
      include Hana::SchemaStatements
      include Hana::Quoting

      def initialize(connection, logger, pool, config)
        super(connection, logger, pool)

        @schema_cache = Hana::SchemaCache.new self
        @visitor = Arel::Visitors::Hana.new self

        @connection_options = config

        connect
        setup_schema
      end

      def connect
        @connection =
          if @connection_options[:dsn].include?(';')
            driver = ODBC::Driver.new.tap do |d|
               d.name = @connection_options[:dsn_name] || 'Driver1'
               d.attrs = @connection_options[:dsn].split(';').map { |atr| atr.split('=') }.reject { |kv| kv.size != 2 }.reduce({}) { |h, kv| k, v = kv ; h[k] = v ; h }
             end
            ODBC::Database.new.drvconnect(driver)

          else
            ODBC.connect @connection_options[:dsn], @connection_options[:username], @connection_options[:password]
          end.tap do |c|
            begin
              c.use_time = true
              c.use_utc = ActiveRecord::Base.default_timezone == :utc
            rescue => e
              warn 'Ruby ODBC v0.99992 or higher is required.'
            end
          end
      end

      def setup_schema
        desired_schema = @connection_options[:database]
        unless schemas.include? desired_schema
          create_schema desired_schema
        end
        set_schema desired_schema
      end

      # === Abstract Adapter ========================================== #

      # Returns the human-readable name of the adapter.
      def adapter_name
        'Hana'
      end

      def clear_cache!
        @statements.clear
      end

      # Should primary key values be selected from their corresponding
      # sequence before the insert statement? If true, next_sequence_value
      # is called before each insert to set the record's primary key.
      # This is false for all adapters but Firebird.
      #
      # This value is set to false, because the adapter auto-generate a
      # sequence for each table. If this value would be set to true the
      # user has to spezify a sequence for each table in the migration.
      def prefetch_primary_key?(table_name = nil)
        true
      end

      def requires_reloading?
        false
      end

      def supports_bulk_alter?
        false
      end

      def supports_count_distinct?
        true
      end

      def supports_ddl_transactions?
        false
      end

      def supports_explain?
        true
      end

      def supports_index_sort_order?
        false
      end

      def supports_migrations?
        true
      end

      def supports_primary_key?
        true
      end

      def supports_savepoints?
        false
      end

      def supports_statement_cache?
        true
      end

      def primary_key(table_name)
        row = select_values "SELECT COLUMN_NAME FROM CONSTRAINTS WHERE SCHEMA_NAME=\'#{@connection_options[:database]}\' AND TABLE_NAME=\'#{table_name}\' AND IS_PRIMARY_KEY=\'TRUE\'"
        row && row.first
      end

      # === Abstract Adapter (Connection Management) ================== #

      def active?
        @connection.do 'SELECT 1 FROM DUMMY'
        true
      rescue ODBC::Error
        false
      end

      def reconnect!
        disconnect!
        connect
        active?
      end

      def disconnect!
        @connection.disconnect rescue nil
      end

      def reset!
        clear_cache!
        super
      end
    end
  end # module ConnectionAdapters
end # module ActiveRecord
