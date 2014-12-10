tasks = Rake.application.instance_variable_get '@tasks'

%w[db:create db:drop db:test:purge].each do |task_name|
  tasks["#{task_name}:original"] = tasks.delete(task_name)
end

namespace 'db' do
  task :create => [:load_config, :rails_env] do
    config = ActiveRecord::Base.configurations[::Rails.env]
    if config['adapter'] == 'hana'
      ActiveRecord::Base.establish_connection(config)
      ActiveRecord::Base.connection.execute("CREATE SCHEMA \"#{config['database']}\" OWNED BY #{config['username']}")
    else
      Rake::Task['db:create:original'].invoke
    end
  end

  task :drop => [:load_config, :rails_env] do
    config = ActiveRecord::Base.configurations[::Rails.env]
    if config['adapter'] == 'hana'
      ActiveRecord::Base.establish_connection(config)
      ActiveRecord::Base.connection.execute("DROP SCHEMA \"#{config['database']}\" CASCADE")
    else
      Rake::Task['db:drop:original'].invoke
    end
  end

  namespace :schema do
    task :load => 'db:migrate'
  end

  namespace :test do
    task :purge => [:environment, :load_config] do
      test_schema = ActiveRecord::Base.configurations['test']['database']
      connection = ActiveRecord::Base.connection
      begin
        connection.execute("DROP SCHEMA \"#{test_schema}\" CASCADE")
      rescue => exception
        unless exception.message =~ /invalid schema name/i
          raise exception
        else
          connection.execute("CREATE SCHEMA \"#{test_schema}\"")
        end
      end
    end
  end
end
