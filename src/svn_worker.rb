# Copyright (c) 2013 MaestroDev.  All rights reserved.
require 'maestro_plugin'
require 'maestro_shell'

module MaestroDev
  module Plugin

    class SvnWorker < Maestro::MaestroWorker

      def checkout
        validate_checkout_parameters

        # save the path for later tasks
        set_field('scm_path', @path)
        set_field('svn_path', @path)

        command = "checkout"
        args = "#{@url} #{@path}"
        if File.exists? @path and @clean_working_copy
          write_output("\nDeleting old path - #{@path}\n", :buffer => true)
          FileUtils.rm_rf @path
        elsif File.exists? @path
          command = "update"
          args = @path
        end

        write_output("\nChecking Out repo - #{@url} to #{@path}\n", :buffer => true)

        checkout_script =<<-CHECKOUT
#{@env}#{@executable} #{command} --non-interactive --trust-server-cert #{@options} #{args}
CHECKOUT

        shell = Maestro::Util::Shell.new
        write_output("\nRunning command:\n----------\n#{checkout_script.chomp}\n----------\n")
        shell.create_script(checkout_script)
        shell.run_script_with_delegate(self, :on_output)

        raise PluginError, "Error Checking Out repo #{@url}" unless shell.exit_code.success?

        latest_rev = read_output_value('revision')
        local_rev = get_revision

        save_output_value('revision', local_rev)
        save_output_value('url', @url)
        save_output_value('commit_id', local_rev)  # Same as revision, but name should be consistent with other VCS

        if !latest_rev.nil? and !latest_rev.empty? and latest_rev == local_rev and !get_field('force_build')
          write_output "\nRevision From Previous Build #{latest_rev} Equals Latest From Repo #{local_rev} - Build Not Needed"
          not_needed
        end
      end

      def copy
        validate_copy_parameters

        write_output("\nsvn copying #{@source}  revision: #{@revision} to #{@destination} with the message '#{@message}'\n", :buffer => true)

        command_string = "#{@source}"
        command_string = command_string + " -r #{@revision} " unless @revision.empty?
        command_string = command_string + " #{@destination}"
        command_string = command_string + " -m '#{@message}'" unless @message.empty?

        copy_script =<<-COPY
#{@env}#{@executable} copy #{@options} #{command_string}
COPY

        shell = Maestro::Util::Shell.new
        write_output("\nRunning command:\n----------\n#{copy_script.chomp}\n----------\n")
        shell.create_script(copy_script)
        shell.run_script_with_delegate(self, :on_output)

        raise PluginError, "Error svn copying #{@source} to #{@destination}" if !shell.exit_code.success?
      end

      def on_output(text)
        write_output(text, :buffer => true)
      end

      private

      def valid_executable?(executable)
        Maestro::Util::Shell.run_command("#{executable} --version")[0].success?
      end

      def default_path
        s = get_field('composition', '').downcase.strip.gsub(' ', '-').gsub(/[^\w-]/, '')
        File.expand_path("~/wc/#{s}-#{get_field('composition_id', '')}")
      end

      def validate_common_parameters
        errors = []

        @executable = get_field('executable', 'svn')
        @environment = get_field('environment', '')
        @options = get_field('options', '')
        @env = @environment.empty? ? "" : "#{Maestro::Util::Shell::ENV_EXPORT_COMMAND} #{@environment.gsub(/(&&|[;&])\s*$/, '')} && "

        errors << 'svn not installed (or not on path)' if !valid_executable?(@executable)

        errors
      end

      def validate_checkout_parameters
        errors = validate_common_parameters

        @path = get_field('path') || default_path
        save_output_value('repo_path', @path)

        @url = get_field('url', '')
        @clean_working_copy = get_boolean_field('clean_working_copy')
        @force_build = get_boolean_field('force_build')

        errors << 'no svn url specified' if @url.empty?

        if !errors.empty?
          raise ConfigError, "Configuration errors: #{errors.join(', ')}"
        end
      end

      def validate_copy_parameters
        errors = validate_common_parameters

        @source = get_field('source', '')
        @revision = get_field('revision', '')
        @destination = get_field('destination', '')
        @message = get_field('message', '')

        errors << 'no source specified' if @source.empty?
        errors << 'no destination specified' if @destination.empty?
        errors << "Destination '#{@destination}' already exists" if !@destination.empty? && File.exists?(@destination)

        if !errors.empty?
          raise ConfigError, "Configuration errors: #{errors.join(', ')}"
        end
      end

      def get_revision
        return unless File.exists?(@path)
        svn_info = Maestro::Util::Shell.new
        svn_info.create_script("cd #{@path} ; svn info")
        svn_info.run_script
        if svn_info.exit_code.success?
          svn_info.output.match(/Revision\:\s*(\w+)/)[1]
        else
          raise PluginError, "Failed To Detect SVN Revision Number From #{@path}"
        end
      end
    end
  end
end
