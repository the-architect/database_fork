require 'erb'

# this is very Rails specific
# TODO: make this work with other frameworks too :)
class LoadDatabaseConfig
  def initialize(root_dir)
    @root_dir = root_dir
  end

  def config
    @config ||= YAML.load(ERB.new(open(File.join(@root_dir, 'config', 'database.yml')).read).result)
  end
end