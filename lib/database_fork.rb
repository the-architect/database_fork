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
  def initialize(root_dir, logger = Logger.new(STDOUT))
    @root_dir = root_dir
    @config_file = File.join(@root_dir, '.db_forks.yml')
    @logger = logger
    @commands = []
  end

  # TODO: simplify this somehow
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
        case ask_user("Create database: '#{fork_db_name}'? (y(es), n(no), enter=ignore)")
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
      reset_env
    end

    save_config
  end


  def ask_user(question)
    log_info question
    IO.new(IO.sysopen('/dev/tty'), 'r').gets.chomp
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

  # TODO: refactor to adapter
  def create_dump(env = 'development')
    run_command %Q{mysqldump #{connection_params(env)} --routines --triggers -C #{source_db(env)} > #{dump_file_path(env)}}, "dumping #{source_db(env)}"
  end

  # TODO: refactor to adapter
  def create_database(env = 'development')
    run_command %Q{mysql #{connection_params(env)} -e "CREATE DATABASE IF NOT EXISTS #{fork_db_name(env)} CHARACTER SET '#{character_set}' COLLATE '#{collation}';"}, "create database #{fork_db_name(env)}"
  end

  # TODO: refactor to adapter
  def import_dump(env = 'development')
    run_command %Q{mysql #{connection_params(env)} -C -A -D#{fork_db_name(env)} < #{dump_file_path(env)}}, 'importing dump'
  end

  def delete_dump_file(env = 'development')
    run_command "rm #{dump_file_path(env)}", 'cleanup'
  end

  def reset_env
    log_info 'Resetting fork information'
    run_command "rm ./tmp/DATABASE_FORK_DEVELOPMENT", 'rm DATABASE_FORK_DEVELOPMENT'
    run_command "rm ./tmp/DATABASE_FORK_TEST", 'rm DATABASE_FORK_TEST'
  end

  def export_env
    run_command "echo #{fork_db_name('development')} > ./tmp/DATABASE_FORK_DEVELOPMENT", 'setting DATABASE_FORK_DEVELOPMENT'
    run_command "echo #{fork_db_name('test')} > ./tmp/DATABASE_FORK_TEST", 'setting DATABASE_FORK_TEST'
  end

  def run_command(command, message, dry_run = false)
    log_info message
    log_debug command
    @commands << [command, message]
    `#{command}` unless dry_run
  end

  def dump_file_path(env = 'development')
    File.join(@root_dir, 'tmp', "dump_#{env}.sql")
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
    @app_connection ||= YAML.load(ERB.new(open(File.join(@root_dir, '..', '..', 'config', 'database.yml')).read).result)
  end

  def current_branch
    @current_branch ||= `git rev-parse --abbrev-ref HEAD`.strip.gsub('/', '_')
  end

  DEFAULTS = {
    'check_branch_name_regex' => '^feature_',
    'ignore' => [],
    'environments' => %w(development test)
  }

  def config
    @config ||= DEFAULTS.merge(YAML.load(open(@config_file).read)) rescue DEFAULTS
  end

  def save_config
    File.open(@config_file, 'w') do |f|
      f.puts @config.to_yaml
    end
  end
end
