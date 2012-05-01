require 'java'
require 'rbconfig'
require 'rubygems'
require 'rubygems/format'

module Hourglass
  class Launcher
    include java.lang.Runnable
    include_package 'java.awt'

    def say(string)
      puts string
    end

    def find_hourglass_dir
      dir =
        if ENV['HOURGLASS_HOME']
          ENV['HOURGLASS_HOME']
        else
          case Config::CONFIG['host_os']
          when /mswin|windows/i
            # Windows
            File.join(ENV['APPDATA'], "hourglass")
          else
            if ENV['HOME']
              File.join(ENV['HOME'], ".hourglass")
            else
              raise "Can't figure out where Hourglass lives! Try setting the HOURGLASS_HOME environment variable"
            end
          end
        end
      if !File.exist?(dir)
        begin
          Dir.mkdir(dir)
        rescue SystemCallError
          raise "Can't create Hourglass directory (#{dir})! Is the parent directory accessible?"
        end
      end
      if !File.writable?(dir)
        raise "Hourglass directory (#{dir}) is not writable!"
      end
      @hourglass_dir = File.expand_path(dir)

      @gems_dir = File.join(@hourglass_dir, "gems")
      Gem.use_paths(@gems_dir, [@gems_dir])
    end

    def install_or_update_hourglass
      # Borrowing ideas from JRuby's maybe_install_gems command

      gem_name = "hourglass"

      # Want the kernel gem method here; expose a backdoor b/c RubyGems 1.3.1 made it private
      Object.class_eval { def __gem(g); gem(g); end }
      gem_loader = Object.new

      command = "install"
      begin
        gem_loader.__gem(gem_name)
        command = "update"
        say("Checking for updates...")
      rescue Gem::LoadError
        say("Installing Hourglass...")
      end

      Object.class_eval { remove_method :__gem }

      old_paths = Gem.paths
      old_argv = ARGV.dup
      ARGV.clear
      ARGV.push(command, "-i", @gems_dir, gem_name)
      begin
        load Config::CONFIG['bindir'] + "/gem"
      rescue SystemExit => e
        # don't exit in case of 0 return value from 'gem'
        exit(e.status) unless e.success?
      end
      ARGV.clear

      # TODO: cleanup

      ARGV.push(*old_argv)
      Gem.paths = {"GEM_HOME" => old_paths.home, "GEM_PATH" => old_paths.path}
    end

    def start_hourglass
      version = ">= 0"
      gem 'hourglass', version
      load Gem.bin_path('hourglass', 'hourglass', version)
    end

    def run
      find_hourglass_dir
      install_or_update_hourglass
      start_hourglass
    end
  end
end
