module ActiveRecord
  module Hana
    module Adapter
      class OutputParameter
        attr_accessor :value

        def initialize(value = nil)
          self.value = value
        end

        def to_s
          value.to_s
        end
      end
    end
  end
end
