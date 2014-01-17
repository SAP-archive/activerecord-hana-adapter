module ActiveRecord
  module ConnectionAdapters
    module Hana
      module DatabaseLimits
        
        def column_name_length
          127
        end

        def columns_per_multicolumn_index
          16
        end

        def columns_per_table
          1000
        end

        def in_clause_length
          # TODO: Check this
          65536
        end

        def indexes_per_table
          1023
        end

        def index_name_length
          127
        end

        def joins_per_query
          # TODO: Check this
          256
        end

        def sql_query_length
          # TODO: Check this
          65536 * 4096
        end

        def table_alias_length
          128
        end

        def table_name_length
          127
        end
        
      end
    end
  end
end
