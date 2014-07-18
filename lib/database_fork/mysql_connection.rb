class MysqlConnection
  def initialize(config)
    @config = config
  end

  def params
    key_mapping = {
      'username' => 'user',
      'password' => 'password',
      'socket' => 'socket',
      'host' => 'host',
      'port' => 'port'
    }

    @config.inject(Hash.new) do |akk, tupel|
      key, value = *tupel

      akk[key_mapping[key.to_s]] = value if key_mapping.key?(key.to_s)
      akk
    end.map do |tupel|
      key, value = *tupel

      "--#{key}=#{value}"
    end.sort.join(' ')
  end
end