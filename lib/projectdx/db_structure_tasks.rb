require File.dirname(__FILE__) + '/../database_operations'

namespace :db do
  Rake::Task['db:structure:dump'].clear_actions() if Rake::Task.task_defined?('db:structure:dump')
  namespace :structure do
    desc "Dump the database structure to a SQL file"
    task :dump do
      if File.exists?('db/ci_structure.sql')
        STDERR.puts "CI environment detected: not dumping schema"
      else
        ops = DatabaseOperations.new(:stage => 'development')
        ops.config && ops.dump_database_schema!('db/development_structure.sql')
      end
    end
  end

  desc "Load db objects from lib/sql_erb into test database"
  task :load_db_objects => [:environment] do
    DatabaseOperations.new.load_views_and_triggers!
  end

  desc "Clone reference DB"
  task :clone_reference_database => [:environment] do
    DatabaseOperations.new.clone_reference_database!
  end
end
