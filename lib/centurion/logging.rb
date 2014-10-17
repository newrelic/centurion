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

  def echo(command)
    if Thread.list.find_all { |t| t.status == 'run' }.count > 1
      run_without_echo(command)
    else
      run_with_echo(command)
    end
  end

  def run_without_echo(command)
    output = Queue.new
    output_thread = Thread.new do
      while true do
        begin
          puts output.pop
        rescue => e
          info "Rescuing... #{e.message}"
        end
      end
    end

    IO.popen(command) do |io|
      io.each_line { |line| output << line }
    end

    output_thread.kill
    validate_status(command)
  end

  def run_with_echo(command)
    $stdout.sync = true
    $stderr.sync = true
    IO.popen(command) do |io|
      io.each_char { |char| print char }
    end
    validate_status(command)
  end

  def validate_status(command)
    unless $?.success?
      raise "The command failed with a non-zero exit status: #{$?.exitstatus}. Command: '#{command}'"
    end
  end

  private

  def log(*args)
    @@logger ||= Logger.new(STDOUT)
  end
end
