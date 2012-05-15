require 'open3'
require 'tempfile'
class DatabaseOperations
  def self.pg(cfg, cmd, opts = {})
    ENV['PGPASSWORD'] = cfg["password"]

    args = []
    args << %{-h "#{cfg["host"]}"}     if cfg["host"]
    args << %{-U "#{cfg["username"]}"} if cfg["username"]
    args << %{-p "#{cfg["port"]}"}     if cfg["port"]
    args << %{-w}

    pipe = opts[:pipe] ? " | #{opts[:pipe]}" : ""

    %x{#{cmd} #{args.join(' ')} "#{cfg['database']}"#{pipe}}
  ensure
    ENV.delete('PGPASSWORD')
  end

  def self.load_database_schema!(cfg, file)
    pg(cfg, 'createdb') unless pg(cfg, "psql -l") =~ /^ #{cfg['database']}\s*\|/m

    Tempfile.open('initdb') do |f|
      f.puts "set client_min_messages=error;"
      f.flush
      pg(cfg, "psql -f #{f.path}")
    end

    pg cfg, %{psql -f "#{file}"}
  end

  def self.dump_database_schema!(cfg, file)
    search_path = cfg["schema_search_path"]
    search_path = search_path.split(',').map{|x| "--schema=#{x}"}.join(' ') if search_path

    File.open(Rails.root.join(file), "w") { |f|
      f.puts "begin;"
      f.write pg(cfg, %{pg_dump -s}, :pipe => %{perl -ne 'print unless /COPY.*spatial_ref_sys/ .. /\\x5c\\x2e/'})
      f.write pg(cfg, %{pg_dump -a -t schema_migrations})
      f.puts "commit;"
    }
  end

  def self.load_views_and_triggers!(env=Rails.env)
    cfg = ActiveRecord::Base.configurations[env]
    unless pg(cfg, "createlang -l") =~ /plpgsql/
      pg(cfg, "createlang plpgsql")
    end

    output = nil 

    Tempfile.open('load_views') do |temp|

      Dir.glob(Rails.root.join('lib', 'sql_erb', '[0-9]*.sql.erb')).sort_by { |f| ('0.%s' % File.split(f).last.gsub(/\D.*/,'')).to_f }.each do |fpath|
        temp.puts File.open(fpath){|io| ERB.new(io.read).result }
      end 
      temp.flush
      output = pg cfg, %{psql --single-transaction -f #{temp.path} }
    end 
    output
  end 
end
