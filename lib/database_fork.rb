require 'yaml'
require 'erb'
require 'logger'

class DatabaseFork

  class << self
    #  call this at the end of your application.rb file
    def setup_env(env, root_dir)
      db_fork_var = "DATABASE_FORK_#{env}".upcase
      db_fork_file = File.join(root_dir, 'tmp', db_fork_var)
      if File.exists?(db_fork_file)
        ENV[db_fork_var] = open(db_fork_file).read.strip
      end
    end
  end

  # use DatabaseFork.new.run in your post-checkout hook
  def initialize(config_file = '.db_forks.yml', logger = Logger.new(STDOUT))
    @config_file = config_file
    @logger = logger
  end

  def run
    if config['ignore'].include?(current_branch)
      log_info 'This branch name is ignored in .db_fork.yml config. Skipping along.'
      reset_env
    elsif Regexp.new(config['check_branch_name_regex']).match(current_branch)
      log_info 'branch qualified for database forking'

      if fork_exists?
        log_info 'database fork already exists'
        export_env
      else
        log_info "Create a database fork '#{fork_db_name}'? [y|n|enter=ignore]"

        # trick to read user input:
        decision = IO.new(IO.sysopen('/dev/tty'), 'r').gets.chomp

        case decision
          when 'y'
            create_database_fork!
            export_env
          when 'n'
            # do nothing
            reset_env
          else
            config['ignore'] << current_branch
            reset_env
        end
      end
    else
      log_info 'not a feature branch. not creating database fork.'
      reset_env
    end

    save_config
  end

  def create_database_fork!
    config['environments'].each do |env|
      log_info "creating database fork '#{fork_db_name(env)}' from #{source_db(env)}"

      create_dump(env)
      create_database(env)
      import_dump(env)
      delete_dump_file(env)
    end
  end

  def create_dump(env = 'development')
    run_command %Q{mysqldump #{connection_params(env)} --routines --triggers -C #{source_db(env)} > #{dump_file_path(env)}}, "dumping #{source_db(env)}"
  end

  def create_database(env = 'development')
    run_command %Q{mysql #{connection_params(env)} -e "CREATE DATABASE IF NOT EXISTS #{fork_db_name(env)} CHARACTER SET '#{character_set}' COLLATE '#{collation}';"}, "create database #{fork_db_name(env)}"
  end

  def import_dump(env = 'development')
    run_command %Q{mysql #{connection_params(env)} -C -A -D#{fork_db_name(env)} < #{dump_file_path(env)}}, 'importing dump'
  end

  def delete_dump_file(env = 'development')
    run_command "rm #{dump_file_path(env)}", 'cleanup'
  end

  def reset_env
    run_command "rm ./tmp/DATABASE_FORK_DEVELOPMENT", 'rm DATABASE_FORK_DEVELOPMENT'
    run_command "rm ./tmp/DATABASE_FORK_TEST", 'rm DATABASE_FORK_TEST'
  end

  def export_env
    run_command "echo #{fork_db_name('development')} > ./tmp/DATABASE_FORK_DEVELOPMENT", 'setting DATABASE_FORK_DEVELOPMENT'
    run_command "echo #{fork_db_name('test')} > ./tmp/DATABASE_FORK_TEST", 'setting DATABASE_FORK_TEST'
  end

  def run_command(command, message)
    log_info message
    log_debug command
    `#{command}`
  end

  def dump_file_path(env = 'development')
    "./tmp/dump_#{env}.sql"
  end

  # could be queried from source_db:
  def character_set
    config['character_set'] || 'utf8'
  end

  # could be queried from source_db:
  def collation
    config['collation'] || 'utf8_unicode_ci'
  end

  def log_info(message)
    @logger.info message
  end

  def log_debug(message)
    @logger.debug message
  end

  def fork_exists?(env = 'development')
    command = %Q{mysql #{connection_params[env]} -s -N -e "SHOW DATABASES LIKE '#{fork_db_name(env)}';" }
    !`#{command}`.empty?
  end

  # simplify
  # make framework agnostic
  def connection_params(env = 'development')
    @connection_params ||= if ENV['USER'] == 'vagrant'
      %Q{--user=#{app_connection[env]['username']} --password=#{app_connection[env]['password']} --socket=#{app_connection[env]['socket']}}
    else
      %Q{--user=#{app_connection[env]['username']} --password=#{app_connection[env]['password']} --host=#{app_connection[env]['host']} --port=#{app_connection[env]['port']}}
    end
  end

  def fork_db_name(env = 'development')
    "#{source_db(env)}_#{current_branch}".strip
  end

  def source_db(env= 'development')
    app_connection[env]['database']
  end

  def app_connection
    @app_connection ||= YAML.load(ERB.new(open(File.join(File.dirname(__FILE__), '..', '..', 'config', 'database.yml')).read).result)
  end

  def current_branch
    @current_branch ||= `git rev-parse --abbrev-ref HEAD`.strip.gsub('/', '_')
  end

  def config
    @config ||= begin
      config = {
        'check_branch_name_regex' => '^feature_',
        'ignore' => [],
        'environments' => %w(development test)
      }
      config.merge! YAML.load(open(@config_file).read) if File.exists?(@config_file)
      config
    end
  end

  def save_config
    File.open(@config_file, 'w') do |f|
      f.puts @config.to_yaml
    end
  end
end
