require 'logger/colors'
require 'logger'

module Centurion; end

module Centurion::Logging
  def info(*args)
    log.info args.join(' ')
  end

  def warn(*args)
    log.warn args.join(' ')
  end

  def error(*args)
    log.error args.join(' ')
  end

  def debug(*args)
    log.debug args.join(' ')
  end

  private

  def log(*args)
    @@logger ||= Logger.new(STDOUT)
  end
end
