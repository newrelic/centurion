require 'spec_helper'
require 'centurion/project_loader'

module Centurion
  describe ProjectLoader do

    describe "load_project" do
      let(:centurion_config_home) { File.expand_path("../tmp/config/home", __FILE__) }
      let(:root_dir) { File.expand_path("../tmp/working", __FILE__) }

      before do
        ENV["CENTURION_CONFIG_HOME"] = centurion_config_home
        create_project_file("#{centurion_config_home}/config/centurion", "FIRST")
        create_project_file(centurion_config_home, "SECOND")
        create_project_file("#{root_dir}/config/centurion", "THIRD")
        create_project_file(root_dir, "FOURTH")
      end

      after do
        FileUtils.rm_rf(centurion_config_home)
        FileUtils.rm_rf(root_dir)
      end

      it "loads the project file in CENTURION_CONFIG_HOME/config/centurion" do
        ProjectLoader.load_project(root_dir, "foo")
        expect(ProjectLoaderTest.hello).to eql("FIRST")
      end

      it "loads the project file in CENTURION_CONFIG_HOME" do
        FileUtils.rm_rf("#{centurion_config_home}/config/centurion")

        ProjectLoader.load_project(root_dir, "foo")
        expect(ProjectLoaderTest.hello).to eql("SECOND")
      end

      it "loads the project file in WORKING_DIR/config/centurion" do
        FileUtils.rm_rf("#{centurion_config_home}/config/centurion")
        FileUtils.rm_rf(centurion_config_home)

        ProjectLoader.load_project(root_dir, "foo")
        expect(ProjectLoaderTest.hello).to eql("THIRD")
      end

      it "loads the project file in WORKING_DIR" do
        FileUtils.rm_rf("#{centurion_config_home}/config/centurion")
        FileUtils.rm_rf(centurion_config_home)
        FileUtils.rm_rf("#{root_dir}/config/centurion")

        ProjectLoader.load_project(root_dir, "foo")
        expect(ProjectLoaderTest.hello).to eql("FOURTH")
      end

      it "raises an error when the project file could not be found" do
        FileUtils.rm_rf("#{centurion_config_home}/config/centurion")
        FileUtils.rm_rf(centurion_config_home)
        FileUtils.rm_rf("#{root_dir}/config/centurion")
        FileUtils.rm_rf(root_dir)

        expect { ProjectLoader.load_project(root_dir, "foo")
        }.to raise_error(ProjectLoader::FileNotFound)
      end

      def create_project_file(directory, message)
        FileUtils.mkdir_p(directory)
        File.write "#{directory}/foo.rake", <<-MESSAGE
          module ProjectLoaderTest
            def self.hello
              "#{message}"
            end
          end
        MESSAGE
      end
    end

    describe "lookup_path" do
      before do
        ENV["CENTURION_CONFIG_HOME"] = nil
      end

      it "adds the specified directory" do
        expect(ProjectLoader.build_lookup_path("/tmp", "foo")).to eql([
          "/tmp/config/centurion/foo.rake",
          "/tmp/foo.rake"
        ])
      end

      it "prepends the CENTURION_CONFIG_HOME when present" do
        ENV["CENTURION_CONFIG_HOME"] = "/foo/bar"

        expect(ProjectLoader.build_lookup_path("/tmp", "foo")).to eql([
          "/foo/bar/config/centurion/foo.rake",
          "/foo/bar/foo.rake",
          "/tmp/config/centurion/foo.rake",
          "/tmp/foo.rake"
        ])
      end
    end
  end
end

