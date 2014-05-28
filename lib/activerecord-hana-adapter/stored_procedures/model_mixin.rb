module ActiveRecord
  module Hana
    module Adapter
      module ModelMixin
        def self.included(base)
          base.const_set('OutputParameter', OutputParameter)
          base.send(:extend, ClassMethods)
        end

        module ClassMethods
          include ConnectionHelper

          def bind_arguments(sql, arguments = [])
            arguments.each do |argument|
              value = begin
                case argument
                when Date, String, Time
                  "'#{argument}'"
                when Numeric
                  argument.to_s
                when OutputParameter
                  nil
                end
              end
              sql.sub!('?', value) if value
            end
          end
          private :bind_arguments

          def call_stored_procedure(name, arguments = [], options = {}, &block)
            if block
              inject_implicit_output_parameters(options, arguments)
              options[:block] = block
            end
            placeholders = arguments.map { '?' }
            sql = "CALL \"#{name}\"(#{placeholders.join(', ')})"
            relation, output_values = execute_sql(sql, arguments, options)
            map_stored_procedure_results(relation, output_values, options)
          end
          private :call_stored_procedure

          def create_class_method(method_name, procedure_name, options = {})
            singleton_class.send :define_method, method_name do |*args, &block|
              call_stored_procedure(procedure_name, args, options, &block)
            end
          end
          private :create_class_method

          def create_instance_method(method_name, procedure_name, options = {})
            define_method method_name do |*args, &block|
              self.class.call_stored_procedure(procedure_name, args, options, &block)
            end
          end
          private :create_instance_method

          def create_wrapper_methods(method_name, procedure_name, options = {})
            location = options[:location]
            if location == :both || location == :class
              create_class_method(method_name, procedure_name, options)
            end
            if location == :both || location == :instance
              create_instance_method(method_name, procedure_name, options)
            end
          end

          def execute_sql(sql, arguments = [], options = {})
            bind_arguments(sql, arguments)
            relation = fetch_relation(sql, options)
            output_values = fetch_output_values(sql, arguments, options)
            [relation, output_values]
          end
          private :execute_sql

          def fetch_output_values(sql, arguments = [], options = {})
            statement = odbc_connection.prepare(sql)
            prepare_output_buffers(statement, options)
            statement.execute(*options[:output_parameters].map { nil })
            output_values = read_output_buffers(statement, arguments, options)
            statement.drop
            output_values
          end
          private :fetch_output_values

          def fetch_relation(sql, options = {})
            relation = active_record_connection.select_all(sql)
            if (type = options[:class] || options[:type]) || options[:instantiate]
              type ||= self < ActiveRecord::Base ? self : self.class
              relation.map { |record| type.instantiate(record) }
            else
              relation
            end
          end
          private :fetch_relation

          def inject_implicit_output_parameters(options, arguments)
            provided_output_parameters = arguments.select { |arg| arg.is_a?(OutputParameter) }
            (options[:output_parameters].count - provided_output_parameters.count).times do
              arguments << OutputParameter.new
            end
          end
          private :inject_implicit_output_parameters

          def map_sql_type(type)
            case type
            when :bigint
              ODBC::SQL_INTEGER
            when :char
              ODBC::SQL_CHAR
            when :date
              ODBC::SQL_DATE
            when :decimal
              ODBC::SQL_INTEGER
            when :double
              ODBC::SQL_INTEGER
            when :float
              ODBC::SQL_INTEGER
            when :integer
              ODBC::SQL_INTEGER
            when :real
              ODBC::SQL_INTEGER
            when :smallint
              ODBC::SQL_INTEGER
            when :time
              ODBC::SQL_TIME
            when :tinyint
              ODBC::SQL_INTEGER
            when :varchar
              ODBC::SQL_CHAR
            else
              unsupported_type(type)
            end
          end
          private :map_sql_type

          def map_stored_procedure_results(relation, output_values, options = {})
            if relation.try(:first).respond_to?(:with_indifferent_access)
              relation = relation.to_hash unless relation.is_a?(Array)
              relation.map!(&:with_indifferent_access)
            end
            relation = relation.try(:first) if options[:single]
            if (block = options[:block])
              block.call(relation, output_values)
            else
              relation
            end
          end
          private :map_stored_procedure_results

          def prepare_output_buffers(statement, options = {})
            options[:output_parameters].each_with_index do |(name, type), index|
              statement.param_iotype(index, ODBC::SQL_PARAM_OUTPUT)
              statement.param_output_size(index, type_size(type))
              statement.param_output_type(index, map_sql_type(type))
            end
          rescue => exception
            statement.drop
            raise exception
          end
          private :prepare_output_buffers

          def read_output_buffers(statement, arguments = [], options = {})
            output_arguments = arguments.select { |arg| arg.is_a?(OutputParameter) }
            output_values = {}
            options[:output_parameters].each_with_index do |(name, type), index|
              value = statement.param_output_value(index)
              output_arguments[index].value = value
              output_values[name] = value
            end
            output_values
          end
          private :read_output_buffers

          def type_size(type)
            case type
            when :bigint
              8
            when :char
              1
            when :date
              1
            when :decimal
              8
            when :double
              8
            when :float
              4
            when :integer
              4
            when :real
              8
            when :smallint
              2
            when :time
              1
            when :tinyint
              1
            when :varchar
              1
            else
              unsupported_type(type)
            end
          end
          private :type_size

          def unsupported_type(type)
            fail TypeError, "Output parameter type '#{type}' is not supported yet."
          end
          private :unsupported_type

          def use_stored_procedure(procedure_name, *args, &block)
            options = args.extract_options!
            options[:block] = block if block_given?
            options[:location] ||= :class
            options[:output_parameters] ||= {}
            method_name = (options[:as] || procedure_name).to_s
            create_wrapper_methods(method_name, procedure_name, options)
          end
          alias_method :uses_stored_procedure, :use_stored_procedure
        end
      end
    end
  end
end
