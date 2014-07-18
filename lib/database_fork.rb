require 'yaml'
require 'logger'
require 'fileutils'

require_relative 'database_fork/logging'
require_relative 'database_fork/commands'
require_relative 'database_fork/load_database_config'
require_relative 'database_fork/mysql_connection'
require_relative 'database_fork/mysql_fork'

class DatabaseFork
  include Logging
  include Commands

  class << self
    #  call this at the end of your application.rb file
    def setup_env(env, root_dir)
      db_fork_var = "DATABASE_FORK_#{env}".upcase
      db_fork_file = File.join(root_dir, 'tmp', db_fork_var)
      if File.exists?(db_fork_file)
        ENV[db_fork_var] = open(db_fork_file).read.strip
      end
    end

    def reset_all_environments!(root_dir, logger = Logger.new(STDOUT))
      logger.info 'removing DATABASE_FORK_* files'
      FileUtils.rm Dir[File.join(root_dir, 'tmp', 'DATABASE_FORK_*')]
    end

  end

  # use DatabaseFork.new.run in your post-checkout hook
  def initialize(root_dir, logger = Logger.new(STDOUT))
    @root_dir     = root_dir
    @config_file  = File.join(@root_dir, '.db_forks.yml')
    @logger       = logger

    reset_commands!
  end

  # TODO: simplify this somehow
  def run
    if Regexp.new(config['check_branch_name_regex']).match(current_branch)
      log_info 'branch qualified for database forking'

      config['environments'].each do |env|
        adapter = MysqlFork.new(@root_dir, app_connection[env], env, current_branch, @logger)

        if adapter.exists?
          log_info "Database #{adapter.target_name} exists. Skipping."
          adapter.export_env
        else
          case ask_user("Create database: '#{adapter.target_name}'? (y(es), n(no), enter=ignore)")
            when 'y'
              adapter.fork
              adapter.export_env
            when 'n'
              adapter.reset_env
            else
              config['ignore'] << current_branch
              adapter.reset_env
          end
        end

      end

    else
      self.class.reset_all_environments!(@root_dir)
    end

    save_config
  end


  def ask_user(question)
    log_info question
    IO.new(IO.sysopen('/dev/tty'), 'r').gets.chomp
  end

  def app_connection
    @database_config ||= LoadDatabaseConfig.new(@root_dir)
    @database_config.config
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
