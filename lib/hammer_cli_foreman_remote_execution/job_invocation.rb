module HammerCLIForemanRemoteExecution
  class JobInvocation < HammerCLIForeman::Command
    resource :job_invocations

    class ListCommand < HammerCLIForeman::ListCommand
      output do
        field :id, _('Id')
        field :job_name, _('Name')
        field :state, _('Task State')
      end

      def extend_data(invocation)
        JobInvocation.extend_data(invocation)
      end

      build_options
    end

    class InfoCommand < HammerCLIForeman::InfoCommand
      output ListCommand.output_definition do
        field :hosts, _('Hosts')
      end

      def extend_data(invocation)
        JobInvocation.extend_data(invocation)
      end

      build_options do |o|
        o.expand(:none)
      end
    end

    class OutputCommand < HammerCLIForeman::Command
      action :output
      command_name 'output'
      desc _('View the output for a host')

      option '--async', :flag, N_('Do not wait for job to complete, shows current output only')

      def print_data(output)
        line_set = output['output'].sort_by { |lines| lines['timestamp'].to_f }
        since = nil

        line_set.each do |line|
          puts line['output']
          since = line['timestamp']
        end

        if output['refresh'] && !option_async?
          sleep 1
          print_data(resource.call(action, request_params.merge(:since => since), request_headers, request_options))
        end
      end

      build_options do |o|
        o.expand(:all).except(:job_invocations)
        o.without(:since)
      end
    end

    class CreateCommand < HammerCLIForeman::CreateCommand
      include HammerCLIForemanTasks::Async

      success_message _('Job invocation %{id} started')

      option '--inputs', 'INPUTS', N_('Specify inputs from command line'),
        :format => HammerCLI::Options::Normalizers::KeyValueList.new

      # For passing larger scripts, etc.
      option '--input-files', 'INPUT FILES', N_('Read input values from files'),
        :format => ::HammerCLIForemanRemoteExecution::Options::Normalizers::KeyFileList.new

      option '--dynamic', :flag, N_('Dynamic search queries are evaluated at run time')

      def request_params
        params = super

        cli_inputs = option_inputs || {}
        file_inputs = option_input_files || {}
        params['job_invocation']['inputs'] = cli_inputs.merge(file_inputs)

        params['job_invocation']['targeting_type'] = option_dynamic? ? 'dynamic_query' : 'static_query'
        params
      end

      def task_progress(task_or_id)
        print_message(success_message, task_or_id)
        task = task_or_id['dynflow_task']['id']
        super(task)
      end

      build_options do |o|
        o.without(:targeting_type)
      end
    end

    def self.extend_data(invocation)
      invocation['state'] = invocation['dynflow_task'] ? invocation['dynflow_task']['state'] : _('unknown')

      if invocation['targeting'] && invocation['targeting']['hosts']
        invocation['hosts'] = "\n" + invocation['targeting']['hosts'].map { |host| " - #{host['name']}" }.join("\n")
      end

      invocation
    end

    autoload_subcommands
  end

  HammerCLI::MainCommand.subcommand 'job-invocation', _('Manage job invocations'), JobInvocation
end
