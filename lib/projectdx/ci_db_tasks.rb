require File.dirname(__FILE__) + '/../database_operations'

namespace :ci do
  desc 'Create database.yml'
  task :configure_database do
    puts "~~~~~Configuring Database~~~~~~"
    p config = File.read('config/database.ci.yml')
    p host_identifier = `hostname`.strip.gsub('.','_')
    p config.gsub!(/{{hostname}}/m, host_identifier)
    p File.write('config/database.yml', config)
    puts "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
  end
end

namespace :db do
  Rake::Task['db:test:clone_structure'].clear_actions() if Rake::Task.task_defined?('db:test:clone_structure')
  def db_ops
    @db_ops ||= DatabaseOperations.new(:stage => 'test')
  end

  namespace :test do
    desc "Drop and recreate empty test db"
    task :purge => [:environment] do
      db_ops.purge_database
    end

    desc "Recreate the test databases from the development structure"
    task :clone_structure => ["db:test:purge"] do
    # task :clone_structure => [ "db:structure:dump", "db:test:purge"] do
      if File.exists?('db/ci_structure.sql')
        STDERR.puts "CI environment detected"
        db_ops.load_database_schema!('db/ci_structure.sql')
      else
        db_ops.load_database_schema!('db/development_structure.sql')
      end
    end

    desc 'Load views, triggers, and functions from lib/sql_erb'
    task :load_db_objects => [:environment] do
      db_ops.load_views_and_triggers!
    end

    desc "Clone reference DB"
    task :clone_reference_database => [:environment] do
      db_ops.clone_reference_database!
    end
  end
end
