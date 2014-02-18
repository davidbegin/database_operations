require 'open3'
require 'tempfile'
require File.expand_path('../database_helpers.rb', __FILE__)

class DatabaseOperations
  def initialize(opts={})
    @config = opts.delete(:config) || db_config[opts.delete(:stage) || Rails.env]
    @db_functions = DatabaseHelpers.new(@config)
  end

  def config
    @config
  end

  def db_config
    YAML.load_file('config/database.yml')
  end

  def purge_database
    @db_functions.execute_sql([
      "DROP DATABASE IF EXISTS \"#{@config['database']}\"",
      "CREATE DATABASE \"#{@config['database']}\""
    ])
  end

  def load_database_schema!(file)
    @db_functions.pg('createdb') unless @db_functions.pg("psql -l") =~ /^ #{@config['database']}\s*\|/m

    Tempfile.open('initdb') do |f|
      f.puts "set client_min_messages=error;"
      f.flush
      @db_functions.pg("psql -f #{f.path}")
    end

    @db_functions.pg %{psql -f "#{file}"}
  end

  def dump_database_schema!(file)
    search_path = @config["schema_search_path"]
    search_path = search_path.split(',').map{|x| "--schema=#{x}"}.join(' ') if search_path

    File.open(Rails.root.join(file), "w") { |f|
      f.puts "begin;"
      # Dump database but exclude PostGIS artifacts which are created with CREATE EXTENSION:
      f.write @db_functions.pg(%{pg_dump -s -T geometry_columns}, :pipe => %{perl -ne 'print unless /COPY.*spatial_ref_sys/ .. /\\x5c\\x2e/'})
      f.write @db_functions.pg( %{pg_dump -a -t schema_migrations -t schema_info})
      f.puts "commit;"
    }
  end

  def clone_reference_database!
    db_ref = @config['reference_db']
    db_target = @config['database']
    p "Cloning #{db_ref} at #{@config['host']}:#{@config['port']} to #{db_target}"
    p 'Killing background actirvity'
    @db_functions.execute_sql([
      %Q[SELECT pg_terminate_backend(pg_stat_activity.procpid)
                       FROM pg_stat_activity
                       WHERE pg_stat_activity.datname = '#{db_target}';],
      %Q[DROP DATABASE IF EXISTS "#{db_target}"],
      %Q[CREATE DATABASE "#{db_target}" TEMPLATE "#{db_ref}"]])
  end

  def load_views_and_triggers!
    unless @db_functions.pg("createlang -l") =~ /plpgsql/
      @db_functions.pg("createlang plpgsql")
    end

    output = nil

    Tempfile.open('load_views') do |temp|
      line_count = 0
      erb_file_result_starts = []
      Dir.glob(Rails.root.join('lib', 'sql_erb', '[0-9]*.sql.erb')).sort_by { |f| ('0.%s' % File.split(f).last.gsub(/\D.*/,'')).to_f }.each do |fpath|
        erb_result = File.open(fpath){|io| ERB.new(io.read).result }

        first_line = line_count + 1
        line_count += erb_result.lines.count
        erb_file_result_starts << "#{File.split(fpath).last} [#{first_line}..#{line_count}]"

        temp.puts erb_result
      end

      puts "#{erb_file_result_starts * ', '}"

      temp.flush
      output = @db_functions.pg %{psql --single-transaction -f #{temp.path} }
    end
    output
  end
end
