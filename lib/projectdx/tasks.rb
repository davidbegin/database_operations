def copy(src,dst)
 %x{if [ -e #{dst} ]; then mv #{dst} #{dst}.bak; fi; cp #{src} #{dst}}
end

require File.dirname(__FILE__) + '/../database_operations'

# these are here to maintain some tiny bit of backwards compatibility
namespace :ci do
  task :setup => 'setup:default'

  namespace :setup do
    task :default => [:copy_config, :clone_structure]

    task :cucumber => [:copy_config, :clean_logdir, :clean_cache, :default]

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
