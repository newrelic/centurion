require 'colorize'
module Centurion::MesosActions

  def list service
    puts
    puts "Application Summary"
    puts "-------------------------------------------------------------------"
    puts Marathon::App.get(service.name).to_pretty_s
    puts 
    puts "Running Instances"
    puts "-------------------------------------------------------------------"
    tasks = Marathon::Tasks.new(Marathon::Connection.new(Marathon.url))
    tasks.get(service.name).each do |task|
      puts task.to_pretty_s
      puts
    end
  end

  def launch_console service
    Marathon::App.start(service.centurion_to_mesos)
    server = Marathon::Task.get('docker-state').map {|t| t.host}.first
    container = server.find_containers_by_name(service.name)
    begin
      server.attach(container.first['Id'])
    rescue Exception
      delete_app service
    end
  end

  def create_new service
    begin
      Marathon::App.start(service.centurion_to_mesos)
    rescue Marathon::Error::MarathonError => e
      puts "** Cleaning up"
      puts "\n\n #{e}\n\n".red
      exit
    end

    running_count = 0
    service.attach_events do |event_object|

      if event_object['eventType'] == "status_update_event"
        case event_object['taskStatus']
        when "TASK_ERROR"
          puts "** TASK_ERROR: #{event_object['message']}".red
          puts "** Cancelling deploy".red
          delete_app service
          return
        when "TASK_LOST"
          puts "** TASK_LOST: #{event_object['message']}".red
          puts "** Cancelling deploy".red
          delete_app service
          return
        when "TASK_RUNNING"
          puts "** TASK_RUNNING on #{event_object['host']}, ports: #{ event_object['ports'].map {|x| x} }"
          running_count = running_count + 1
          if running_count == service.instances
            puts "** Deploy Succeeded".green
            return
          end
        when "TASK_KILLED"
          puts "** TASK_KILLED: #{event_object['message']}".red
          puts "** Cancelling deploy".red
          delete_app service
          return
        end                                                        
      end
    end
  end

  def delete_app service
    Marathon::App.delete(service.name)
  end

  def with_timeout timeout, &block
    begin
      Timeout::timeout(timeout) {
        yield
      }
    rescue Time::Error
      puts "** Timout. Cancelling deploy".red
      delete_app
    end
  end

  def rolling_upgrade service
    Marathon::App.change(service.name, service.centurion_to_mesos)
      killed_count = 0
      service.attach_events do |event_object|
        if event_object['eventType'] == "status_update_event"
          case event_object['taskStatus']
          when "TASK_ERROR"
            puts "** TASK_ERROR: #{event_object['message']}".red
            puts "** Cancelling deploy".red
            delete_app service
            return
          when "TASK_LOST"
            puts "** TASK_LOST: #{event_object['message']}".red
            puts "** Cancelling deploy".red
            delete_app service
            return
          when "TASK_RUNNING"
            puts "** TASK_RUNNING: #{event_object['message']}".green
          when "TASK_KILLED"
            puts "** TASK_KILLED: #{event_object['message']}".red
            killed_count = killed_count + 1
            if killed_count == service.instances
              puts "** Upgrade Succeeded"
              return
            end 
          end                                                        
        end
      end
  end

end
