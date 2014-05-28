# -*- encoding: utf-8 -*-

module ActiveRecord
  module ConnectionAdapters
    module Hana
      module CoreExt
        module ActiveRecord
          module Relation
            module FinderMethods
              def construct_limited_ids_condition(relation)
                orders = relation.order_values.map { |val| val.presence }.compact
                values = @klass.connection.distinct("#{@klass.connection.quote_table_name table_name}.\"#{primary_key}\"", orders)

                relation = relation.dup

                ids_array = relation.select(values).map { |row| row[primary_key] }
                ids_array.empty? ? fail(ThrowResult) : table[primary_key].in(ids_array)
              end
            end
          end
        end
      end
    end
  end
end

ActiveRecord::Relation.send :include, ActiveRecord::ConnectionAdapters::Hana::CoreExt::ActiveRecord::Relation::FinderMethods
