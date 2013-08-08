def copy(src,dst)
 %x{if [ -e #{dst} ]; then mv #{dst} #{dst}.bak; fi; cp #{src} #{dst}}
end

require File.dirname(__FILE__) + '/../database_operations'

namespace :ci do
  task :setup => 'setup:default'

  namespace :setup do
    task :default => [:copy_config, :clone_structure]

    task :cucumber => [:copy_config, :clean_logdir, :clean_cache, :default]

    task :clone_structure do
      abcs = YAML.load_file('config/database.yml') 
      DatabaseOperations.dump_database_schema!(abcs['reference'], 'db/ci_structure.sql')
      DatabaseOperations.load_database_schema!(abcs['test'], 'db/ci_structure.sql')
      puts %x{env RAILS_ENV=test bundle exec rake db:migrate}
      DatabaseOperations.dump_database_schema!(abcs['test'], 'db/ci_structure.sql')
    end

    task :copy_config do
      ci = YAML.load_file('config/database.ci.yml')
      ci['login']['database'] = '%s-ci-%s' % [ci['login']['application'], %x{hostname}.strip.split('.').first]
      login = ci.delete('login')
      ref = '%s-reference' % login['application']
      environments = login.delete('environments')

      ci['reference'] = login.clone
      ci['reference']['database'] = ref
      ci['development'] = login.clone
      
      environments.each do |e|
        ci[e] = login.clone
      end

      File.rename("config/database.yml", "config/database.yml.bak") if File.exists?("config/database.yml")
  
      File.open('config/database.yml', 'w') do |f| 
        f.write(ci.to_yaml);
      end

      if File.exists?("config/cms_config.deploy.yml")
        File.rename("config/cms_config.yml", "config/cms_config.yml.bak") if File.exists?("config/cms_config.yml")
        copy 'config/cms_config.deploy.yml', 'config/cms_config.yml'
      end
    end
    
    task :clean_cache do
      `rm -f public/javascripts/cache_*.js`
    end

    task :clean_logdir do
      `for f in log/* tmp/*; do if [ -f $f ]; then rm $f ; fi; done`
    end
  end
end

namespace :db do
  Rake::Task['db:structure:dump'].clear_actions()
  namespace :structure do
    desc "Dump the database structure to a SQL file"
    task :dump => :environment do
      if File.exists?('db/ci_structure.sql')
        STDERR.puts "CI environment detected: not dumping schema"
      else 
        abcs = ActiveRecord::Base.configurations
        abcs['development'] && DatabaseOperations.dump_database_schema!(abcs['development'], 'db/development_structure.sql')
      end 
    end 
  end 

  Rake::Task['db:test:clone_structure'].clear_actions()
  namespace :test do
    desc "Recreate the test databases from the development structure"
    task :clone_structure => [ "db:structure:dump", "db:test:purge"] do
      abcs = ActiveRecord::Base.configurations
      if File.exists?('db/ci_structure.sql')
        STDERR.puts "CI environment detected"
        DatabaseOperations.load_database_schema!(abcs['test'], 'db/ci_structure.sql')
      else
        DatabaseOperations.load_database_schema!(abcs['test'], 'db/development_structure.sql')
      end
    end
  end
end
