require 'pg'
class DatabaseHelpers
  def initialize config
    @config = config
  end

  def execute_sql(commands)
    pg_conn = PG::Connection.open(
      :host => @config['host'],
      :port => @config['port'],
      :user => @config['username'],
      :password => @config['password'],
      :dbname => 'postgres',
    )
    commands.each { |command| pg_conn.exec command }
    pg_conn.close
  end

  def pg(cmd, opts={})
    ENV['PGPASSWORD'] = @config["password"]

    args = []
    args << %{-h "#{@config["host"]}"}     if @config["host"]
    args << %{-U "#{@config["username"]}"} if @config["username"]
    args << %{-p "#{@config["port"]}"}     if @config["port"]
    args << %{-w}

    pipe = opts[:pipe] ? " | #{opts[:pipe]}" : ""
    database = "\"#{@config['database']}\""

    %x{#{cmd} #{args.join(' ')} #{database}#{pipe}}
  ensure
    ENV.delete('PGPASSWORD')
  end
end