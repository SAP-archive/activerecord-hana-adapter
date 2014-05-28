# -*- encoding: utf-8 -*-

module ActiveRecord
  module ConnectionAdapters
    module Hana
      class Utils
        class << self
          def unqualify_table_name(table_name)
            table_name.to_s.split('.').last.tr('[]', '')
          end
        end
      end
    end
  end
end
