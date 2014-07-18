module Commands
  def record_command(command, message)
    @commands << [command, message]
  end

  def execute_commands
    @commands.each do |command, message|
      log_info message
      log_debug command
      `#{command}`
    end
  end

  def reset_commands!
    @commands = []
  end
end