require 'arel'

module Arel
  class SelectManager

    def project *projections
      @ctx.projections.concat projections.map { |x|
        case x
          when String
            Nodes::SqlLiteral.new(x.to_s)
          when Symbol
            Nodes::SqlLiteral.new("\"#{x.to_s}\"")
          else
            x
        end
      }
      self
    end

  end
end
