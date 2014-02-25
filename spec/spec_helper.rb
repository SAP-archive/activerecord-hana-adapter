require 'active_record'
require 'rails'
require 'activerecord-hana-adapter'

include ActiveRecord::Hana::Adapter::ConnectionHelper

def create_procedure(name, definition)
  @migration ||= ActiveRecord::Migration.new
  @migration.create_procedure(name) { definition }
end
private :create_procedure

def drop_procedure(name)
  @migration ||= ActiveRecord::Migration.new
  @migration.drop_procedure(name)
end
private :drop_procedure

def establish_connection
  config_path = File.join([Dir.pwd, 'test', 'config.yml'])
  @config ||= YAML.load(File.read(config_path))
  ActiveRecord::Base.establish_connection(@config['default_connection_info'])
end
private :establish_connection

def reset(object)
  receiver = RSpec::Mocks
  unless receiver.respond_to?(:proxy_for)
    receiver = receiver.space
  end
  receiver.proxy_for(object).reset
end
private :reset

def stored_procedures
  sql = "SELECT procedure_name AS \"name\" FROM sys.procedures WHERE schema_name = '#{schema}' ORDER BY \"name\""
  active_record_connection.select_all(sql).map { |each| each['name']}.map(&:to_sym)
end
private :stored_procedures
