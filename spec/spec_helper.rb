require 'rubygems'

require 'logger'
require 'fileutils'
require 'stringio'

def tmp_path
  $tmp_path ||= File.join(File.dirname(__FILE__), 'tmp')
end

def clean_tmp
  FileUtils.mkdir_p(tmp_path) # just in case it does not exist
  FileUtils.rm_r tmp_path
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

