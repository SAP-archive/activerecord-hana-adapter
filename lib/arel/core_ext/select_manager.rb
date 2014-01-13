require 'arel'

module Arel	
	class SelectManager
			
		def project *projections
      @ctx.projections.concat projections.map { |x|
				case x
					when String
						SqlLiteral.new(x.to_s)
					when Symbol
						SqlLiteral.new("\"#{x.to_s}\"")
					else
						x
				end
      }
     	self
    end		

	end
end
