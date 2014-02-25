require 'activerecord-hana-adapter/stored_procedures/connection_helper'
require 'activerecord-hana-adapter/stored_procedures/migration_mixin'
require 'activerecord-hana-adapter/stored_procedures/model_mixin'
require 'activerecord-hana-adapter/stored_procedures/output_parameter'

module ActiveRecord
  module Hana
    module Adapter
      class HanaRailtie < Rails::Railtie
        if defined?(ActiveRecord)
          ActiveRecord::Base.send :include, ModelMixin
          ActiveRecord::Migration.send :include, MigrationMixin
        end

        rake_tasks do
          load 'tasks/hana_database.rake'
          load 'tasks/stored_procedures.rake'
        end
      end
    end
  end
end
