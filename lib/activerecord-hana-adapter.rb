require "activerecord-hana-adapter/version"

module Activerecord
  module Hana
    module Adapter
	class HanaRailtie < Rails::Railtie
		rake_tasks do
			load 'active_record/connection_adapters/hana/core_ext/railties/hana_database.rake'
		end
	end
    end
  end
end
