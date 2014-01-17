require 'arel'

module Arel
  module Visitors
    class Hana < Arel::Visitors::ToSql
    
    end
  end
end

Arel::Visitors::VISITORS['hana'] = Arel::Visitors::Hana
