require "activerecord-hana-adapter/version"

module Activerecord
  module Hana
    module Adapter
      class HanaRailtie < Rails::Railtie
        rake_tasks do
          load 'tasks/hana_database.rake'
        end
      end
    end
  end
end
