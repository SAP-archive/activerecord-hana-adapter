# Custom db:create Task
tasks = Rake.application.instance_variable_get '@tasks'
tasks['db:create:original'] = tasks.delete 'db:create'

namespace 'db' do
  task 'create' do
    ActiveRecord::Base.configurations = YAML::load(IO.read('config/database.yml'))
    config = ActiveRecord::Base.configurations[::Rails.env]
    if config['adapter'] == 'hana' 
      ActiveRecord::Base.establish_connection(config)
      ActiveRecord::Base.connection.execute("DROP SCHEMA \"#{config['database']}\" CASCADE")
      ActiveRecord::Base.connection.execute("CREATE SCHEMA \"#{config['database']}\" OWNED BY #{config['username']}")
    else
      Rake::Task['db:create:original'].invoke
    end
  end
end


# Custom db:drop Task
tasks = Rake.application.instance_variable_get '@tasks'
tasks['db:drop:original'] = tasks.delete 'db:drop'

namespace 'db' do
  task 'drop' do
    ActiveRecord::Base.configurations = YAML::load(IO.read('config/database.yml'))
    config = ActiveRecord::Base.configurations[::Rails.env]
    if config['adapter'] == 'hana' 
      ActiveRecord::Base.establish_connection(config)
      ActiveRecord::Base.connection.execute("DROP SCHEMA \"#{config['database']}\" CASCADE")
    else
      Rake::Task['db:drop:original'].invoke
    end
  end
end
