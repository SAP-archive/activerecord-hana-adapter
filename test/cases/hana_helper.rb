HANA_TEST_ROOT       		= File.expand_path(File.join(File.dirname(__FILE__),'..'))
HANA_ASSETS_ROOT     		= File.expand_path(File.join(HANA_TEST_ROOT,'assets'))
HANA_FIXTURES_ROOT   		= File.expand_path(File.join(HANA_TEST_ROOT,'fixtures'))
HANA_MIGRATIONS_ROOT 		= File.expand_path(File.join(HANA_TEST_ROOT,'migrations'))
HANA_SCHEMA_ROOT     		= File.expand_path(File.join(HANA_TEST_ROOT,'schema'))
HANA_MODELS_ROOT     		= File.expand_path(File.join(HANA_TEST_ROOT,'models'))
ACTIVERECORD_TEST_ROOT  = File.expand_path(File.join(Gem.loaded_specs['activerecord'].full_gem_path,'test'))
ENV['ARCONFIG']         = File.expand_path(File.join(HANA_TEST_ROOT,'config.yml'))

$:.unshift ACTIVERECORD_TEST_ROOT

require 'rubygems'
require 'bundler'
Bundler.setup
require 'mocha/api'
require 'active_support/dependencies'
require 'active_record'
require 'active_record/version'
require 'active_record/connection_adapters/abstract_adapter'
require 'minitest-spec-rails'
require 'minitest-spec-rails/init/mini_shoulda'
require 'cases/helper'
require 'models/topic'

GC.copy_on_write_friendly = true if GC.respond_to?(:copy_on_write_friendly?)

ActiveRecord::Migration.verbose = false
ActiveRecord::Base.logger = Logger.new(File.expand_path(File.join(HANA_TEST_ROOT,'debug.log')))
ActiveRecord::Base.logger.level = 0

# Our changes/additions to ActiveRecord test helpers specific for HANA.

module ActiveRecord
  class TestCase < ActiveSupport::TestCase
    class << self
      def connection_mode_odbc? ; ActiveRecord::Base.connection.instance_variable_get(:@connection_options)[:mode] == :odbc ; end
    end

    def connection_mode_odbc? ; self.class.connection_mode_odbc? ; end
  end
end


