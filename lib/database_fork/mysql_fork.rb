require_relative 'db_fork'
require_relative 'mysql_connection'

class MysqlFork < DBFork

  def exists?(dry_run = false)
    command = %Q{mysql #{connection_parameters} -s -N -e "SHOW DATABASES LIKE '#{target_name}';" }
    if dry_run
      reset_commands!
      record_command command, 'query default character set and collation'
    else
      !`#{command}`.empty?
    end
  end

  def connection_parameters
    @connection_parameters ||= MysqlConnection.new(@connection).params
  end

  def create_dump
    record_command %Q{mysqldump #{connection_parameters} --routines --triggers -C #{source_db} > #{dump_file}}, "dumping #{source_db}"
  end

  def source_db
    @connection['database']
  end

  def create_database
    record_command %Q{mysql #{connection_parameters} -e "CREATE DATABASE IF NOT EXISTS #{target_name} CHARACTER SET '#{character_set}' COLLATE '#{collation}';"}, "create database #{@fork_db_name}"
  end

  def import_dump
    record_command %Q{mysql #{connection_parameters} -C -A -D#{target_name} < #{dump_file}}, 'importing dump'
  end

  def query_default_settings(dry_run = false)
    command = %Q{mysql #{connection_parameters} -s -N -e "SELECT DEFAULT_CHARACTER_SET_NAME, DEFAULT_COLLATION_NAME FROM information_schema.SCHEMATA S WHERE schema_name = 'papersmart_dev';"}
    if dry_run
      reset_commands!
      record_command command, 'query default character set and collation'
    else
      @character_set, @collation = *(`#{command}`.("\t"))
    end
  end


end
