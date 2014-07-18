require_relative '../../spec_helper'
require_relative '../../../lib/database_fork/mysql_connection'

describe MysqlConnection do

  let(:connection) { {
    'host' => '127.0.0.1',
    'port' => '3306',
    'username' => 'root',
    'password' => '',
    'database' => 'myapp_development'
  } }

  subject{ MysqlConnection.new(connection) }

  it { expect(subject.params).to eql '--host=127.0.0.1 --password= --port=3306 --user=root' }

end