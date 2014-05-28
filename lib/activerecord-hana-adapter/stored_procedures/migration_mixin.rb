module ActiveRecord
  module Hana
    module Adapter
      module MigrationMixin
        def self.included(base)
          base.send(:include, Methods)
        end

        module Methods
          include ConnectionHelper

          NAME_PLACEHOLDER = '{name}'

          def create_procedure(name, options = {}, &block)
            definition = read_procedure_definition(options, &block).try(:strip)
            fail ArgumentError, "Missing definition for stored procedure '#{name}'." if definition.blank?
            if definition =~ /CREATE PROCEDURE/i
              sql = definition.gsub(NAME_PLACEHOLDER, name.to_s)
            else
              inject_default_options(options)
              sql = procedure_create_statement(options.merge(definition: definition, name: name))
            end
            active_record_connection.execute(sql)
          end
          alias_method :create_stored_procedure, :create_procedure

          def drop_procedure(name)
            active_record_connection.execute("DROP PROCEDURE \"#{name}\"")
          rescue => exception
            raise exception unless exception.message =~ /invalid name/i
          end
          alias_method :drop_stored_procedure, :drop_procedure

          def inject_default_options(options)
            options[:read_only] = true unless options.key?(:read_only)
          end
          private :inject_default_options

          def procedure_create_statement(options = {})
            statement = <<-sql
CREATE PROCEDURE \"#{options[:name]}\"
\tLANGUAGE SQLSCRIPT
\tSQL SECURITY INVOKER#{"\n\tREADS SQL DATA" if options[:read_only]}
AS
BEGIN
\t#{options[:definition]}#{';' unless options[:definition].ends_with?(';')}
END
            sql
            statement
          end
          private :procedure_create_statement

          def read_procedure_definition(options = {}, &block)
            if file_name = options[:file]
              read_procedure_definition_from_file(file_name)
            elsif block_given?
              block.call
            end
          end
          private :read_procedure_definition

          def read_procedure_definition_from_file(file_name)
            path = File.join([Rails.root, 'db', 'procedures', file_name])
            if File.exist?(path)
              File.read(path)
            else
              fail IOError, "File not found: '#{path}'."
            end
          end
          private :read_procedure_definition_from_file
        end
      end
    end
  end
end
