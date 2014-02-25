include ActiveRecord::Hana::Adapter::ConnectionHelper
include ActiveRecord::Hana::Adapter::MigrationMixin

OUTPUT_WIDTH = 175

namespace :db do
  namespace :procedures do
    desc 'Drop stored procedures'
    task :drop => :environment do
      fetch_procedures.each do |procedure|
        drop_procedure(procedure[:name])
      end
    end

    desc 'List stored procedures'
    task :list => :environment do
      procedures = fetch_procedures
      if procedures.empty?
        puts "No stored procedures in schema '#{schema}'."
      else
        list_procedures(procedures)
      end
    end
  end

  task :procedures => 'procedures:list'
end

def fetch_procedures
  sql = "SELECT procedure_oid AS \"id\", procedure_name AS \"name\", input_parameter_count + output_parameter_count AS \"arity\" FROM sys.procedures WHERE schema_name = '#{schema}'"
  procedures = active_record_connection.select_all(sql).map(&:symbolize_keys)
  procedures.each do |procedure|
    sql = "SELECT parameter_name AS \"name\", data_type_name AS \"data_type\", parameter_type AS \"type\" FROM sys.procedure_parameters WHERE procedure_oid = #{procedure[:id]} ORDER BY position"
    procedure[:parameters] = active_record_connection.select_all(sql).map(&:symbolize_keys)
  end
end
private :fetch_procedures

def list_procedures(procedures)
  width = (OUTPUT_WIDTH - 10) / 2
  puts 'Name'.ljust(width) + 'Arity'.ljust(10) + 'Parameters'.ljust(width)
  procedures.sort_by { |procedure| procedure[:name] }.each do |procedure|
    name = truncate_string(procedure[:name], width - 1).ljust(width)
    arity = procedure[:arity].to_s.ljust(10)
    procedure[:parameters].map! { |parameter| "#{parameter[:type]} #{parameter[:name]} #{parameter[:data_type]}"}
    parameters = truncate_string(procedure[:parameters].join(', '), width).ljust(width)
    puts name + arity + parameters
  end
end
private :list_procedures

def truncate_string(string, length)
  if string.length > length
    string.slice(0..length - 4) + '...'
  else
    string
  end
end
private :truncate_string
