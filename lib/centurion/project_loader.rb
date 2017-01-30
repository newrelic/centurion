module Centurion
  module ProjectLoader

    def self.load_project(working_directory, project_name)
      lookup_path = build_lookup_path(working_directory, project_name)
      project_file = lookup_path.detect { |path| File.exists?(path) }

      if project_file
        load(project_file)
      else
        raise FileNotFound.new(lookup_path)
      end
    end

    def self.build_lookup_path(working_directory, project_name)
      centurion_config_home = ENV["CENTURION_CONFIG_HOME"]
      project_name = "#{project_name}.rake"
      lookup_path = []

      if centurion_config_home
        lookup_path << build_path(centurion_config_home, "config", "centurion", project_name)
        lookup_path << build_path(centurion_config_home, project_name)
      end

      lookup_path << build_path(working_directory, "config", "centurion", project_name)
      lookup_path << build_path(working_directory, project_name)

      lookup_path
    end

    def self.build_path(*segments)
      path = File.join(segments)
      File.expand_path(path)
    end

    class FileNotFound < StandardError

      def initialize(lookup_path)
        @lookup_path = lookup_path
      end

      def message
        text = "\nCould not find a project file in any of the following locations: "
        text << @lookup_path.map { |path| "\n  - #{path}" }.join
        text << "\n\n" # Add a few lines of separation between the message and stack trace
        text
      end
    end

  end
end

