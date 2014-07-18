require_relative '../../spec_helper'
require_relative '../../../lib/database_fork/mysql_fork'

describe MysqlFork do

  let(:connection) { {
    'host' => '127.0.0.1',
    'port' => '3306',
    'username' => 'root',
    'password' => '',
    'database' => 'myapp_development'
  } }

  let(:branch_name){ 'feature_branch' }
  let(:env){ 'development' }

  it 'loads correctly' do
    MysqlFork.new(tmp_path, connection, env, branch_name, Logger.new(StringIO.new))
  end

  describe 'with connection configuration' do
    let(:dev){  }

    subject{ MysqlFork.new(tmp_path, connection, env, branch_name, Logger.new(StringIO.new))}

    it{ expect(subject.target_name).to eql 'myapp_development_feature_branch' }

    it 'fork commands' do
      subject.fork(true)
      expect(subject.commands).to_not be_empty
    end

    it 'dump_file' do
      expect(subject.dump_file).to match(%r{tmp/dump_myapp_development.sql$}i)
    end

    it 'create_dump' do
      subject.create_dump
      commands = subject.commands
      expect(commands.size).to eql 1
      expect(commands[0][0]).to match(%r{--routines --triggers -C #{connection['database']} >})
    end

    it 'create_database' do
      subject.create_database
      commands = subject.commands
      expect(commands.size).to eql 1
      expect(commands[0][0]).to match(%r{-e "CREATE DATABASE IF NOT EXISTS #{connection['database']}_#{branch_name} CHARACTER SET 'utf8' COLLATE 'utf8_unicode_ci';"})
    end

    it 'source_db' do
      expect(subject.source_db).to eql connection['database']
    end

  end



end