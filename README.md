# DatabaseFork

Create a copy of your development and test databases when you switch git branches.

## Installation

Add this line to your application's Gemfile:

    gem 'database_fork', '>= 0.0.5'

And then execute:

    $ bundle
    
Add this file to your .gitignore:

    .db_forks.yml

Add the git hook:

    touch .git/hooks/post-checkout
    sudo chmod +x .git/hooks/post-checkout
    
Now add this to the .git/hooks/post-checkout file:
    
    #!/usr/bin/env ruby
    if File.exists?(File.join(ENV['PWD'], 'Gemfile'))
      require 'rubygems'
      require 'bundler/setup'
      require 'database_fork'
    
      DatabaseFork.new(ENV['PWD']).run
    else
      puts "DatabaseFork: No Gemfile found in #{ENV['PWD']}. Run from to your Application's root!"
    end

Rails: add this line at the end of your application.rb:
    
    unless Rails.env.production?
      begin
        DatabaseFork.setup_env(Rails.env, Rails.root)
      rescue LoadError
        'DatabaseFork not available'
      end
    end

## Contributing

1. Fork it ( https://github.com/[my-github-username]/database_fork/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
