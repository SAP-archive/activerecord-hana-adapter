module ActiveRecord
  module Hana
    module Adapter
      module ConnectionHelper
        def active_record_connection
          ActiveRecord::Base.connection
        end
        private :active_record_connection

        def odbc_connection
          active_record_connection.instance_variable_get(:@connection)
        end
        private :odbc_connection

        def schema
          active_record_connection.instance_variable_get(:@connection_options)[:database]
        end
        private :schema
      end
    end
  end
end
