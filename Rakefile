#!/usr/bin/env rake
require "bundler/gem_tasks"
require 'rake'
require 'rake/testtask'
require 'rails'

def test_libs(mode='hana')
  ['lib',
   'test',
   "#{File.join(Gem.loaded_specs['activerecord'].full_gem_path,'test')}"]
end

def test_files
  return ENV['TEST_FILES'].split(',').sort if ENV['TEST_FILES']
  if ::Rails::VERSION::MAJOR >= 4
    files  = Dir.glob("test/cases/v4/*_test_hana.rb").sort
  else
    files  = Dir.glob("test/cases/v3/*_test_hana.rb").sort
  end
  
  #ar_path = Gem.loaded_specs['activerecord'].full_gem_path
  #ar_cases = Dir.glob("#{ar_path}/test/cases/**/*_test.rb")
  #adapter_cases = Dir.glob("#{ar_path}/test/cases/adapters/**/*_test.rb")
  #files += (ar_cases-adapter_cases).sort
  files
end

task :test => ['test:hana']
task :default => [:test]

namespace :test do

  ['hana'].each do |mode|
		# Fix some issues inside ActiveRecords schema.rb

		require 'fileutils'

		ar_test_root     = File.expand_path(File.join(Gem.loaded_specs['activerecord'].full_gem_path,'test'))
		ar_schema_file   = File.expand_path(File.join(ar_test_root,'schema/schema.rb'))

		content     = File.read(ar_schema_file)

		new_content = content.gsub(/ALTER TABLE fk_test_has_fk ADD/, "ALTER TABLE \#{quote_table_name 'fk_test_has_fk'} ADD")
		new_content = new_content.gsub(/ALTER TABLE lessons_students ADD/, "ALTER TABLE \#{quote_table_name 'lessons_students'} ADD")

		File.open(ar_schema_file, "w") {|file| file.write new_content}

    Rake::TestTask.new(mode) do |t|
      t.libs = test_libs(mode)
      t.test_files = test_files
      t.verbose = true
    end
  end
  
  task 'hana:env' do
    ENV['ARCONN'] = 'hana'
  end
  
end

task 'test:hana' => 'test:hana:env'

namespace :profile do
  
  ['hana'].each do |mode|
    namespace mode.to_sym do
      
      Dir.glob("test/profile/*_profile_case.rb").sort.each do |test_file|
        
        profile_case = File.basename(test_file).sub('_profile_case.rb','')
        
        Rake::TestTask.new(profile_case) do |t|
          t.libs = test_libs(mode)
          t.test_files = [test_file]
          t.verbose = true
        end
        
      end
      
    end
  end
  
end


