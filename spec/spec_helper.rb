require 'rubygems'

require 'logger'
require 'fileutils'
require 'stringio'

# create && clean up tmp directory

def tmp_path
  File.join(File.dirname(__FILE__), 'tmp')
end

def clean_tmp
  FileUtils.mkdir_p(tmp_path)
  FileUtils.rm_r(Dir[File.join(tmp_path, '*')])
end


RSpec.configure do |c|
  c.mock_with :rspec

  c.treat_symbols_as_metadata_keys_with_true_values = true
  c.filter_run :focus => true
  c.run_all_when_everything_filtered = true

  c.before do
    clean_tmp
  end
end

