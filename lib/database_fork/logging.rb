module Logging
  def log_info(message)
    @logger.info message
  end

  def log_debug(message)
    @logger.debug message
  end
end
