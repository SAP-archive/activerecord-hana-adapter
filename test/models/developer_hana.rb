	puts '############################################ ############'  

class DeveloperCalledDavid < ActiveRecord::Base
	puts '############################################ ############'  
	self.table_name = 'developers'
  default_scope where("\"name\" = 'David'")
end
