require_relative 'logging'
require_relative 'commands'

class DBFork
  include Logging
  include Commands

  # implement this is your adapter:
  def exists?(dry_run = false)
    raise NotImplementedError
  end

  # implement this is your adapter:
  def connection_parameters
    raise NotImplementedError
  end

  def create_dump
    raise NotImplementedError
  end

  def create_database
    raise NotImplementedError
  end

  def import_dump
    raise NotImplementedError
  end

  def query_default_settings(dry_run = false)
    raise NotImplementedError
  end


  def initialize(root_dir, connection, env, branch_name, logger)
    @root_dir = root_dir
    @connection = connection
    @env = env
    @branch_name = branch_name
    @logger = logger

    @character_set = nil
    @collation = nil

    reset_commands!
  end

  attr_accessor :commands

  def fork(dry_run = false)
    reset_commands!

    log_info "creating database fork '#{target_name}' from #{source_db}"

    create_dump
    create_database
    import_dump
    delete_dump_file

    execute_commands unless dry_run
  end

  def target_name
    "#{source_db}_#{@branch_name}"
  end


  def source_db
    @connection['database']
  end

  def reset_env(dry_run = false)
    reset_commands!
    filename = File.join(@root_dir, 'tmp', "DATABASE_FORK_#{@env.upcase}")
    record_command "rm #{filename}", "removing DATABASE_FORK_#{@env.upcase}"
    execute_commands unless dry_run
  end

  def export_env(dry_run = false)
    reset_commands!
    filename = File.join(@root_dir, 'tmp', "DATABASE_FORK_#{@env.upcase}")
    record_command "echo #{target_name} > #{filename}", "setting DATABASE_FORK_#{@env.upcase}"
    execute_commands unless dry_run
  end

  def delete_dump_file
    record_command "rm #{dump_file}", 'cleanup'
  end

  def character_set
    @character_set || 'utf8'
  end

  def collation
    @collation || 'utf8_unicode_ci'
  end

  def dump_file
    File.join(@root_dir, 'tmp', "dump_#{source_db}.sql")
  end

end