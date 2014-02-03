module Siteomatic
	class HostConfig
		def initialize(configFile)
			@@log = Siteomatic::log
			@config = nil
			setupConfig(configFile)
		end

		# Checks that we have a valid region, and if so, sets appropriate s3_zone and s3_endpoint config params.
		def validateS3Region(region)
			return "'#{region}' is not a supported Amazon AWS region" if S3Manager.infoForRegion(region).nil?
			nil
		end

		# Checks that s3cmd exists, and supports the 'ws-create' operation
		def validateS3cmd(cmd)
			return "#{cmd} does not exist" unless File.file?(cmd)
			return "#{cmd} is not executable" unless File.executable?(cmd)

			help = `#{cmd} --help`
			supportsWsCreate = help.index("ws-create") != nil
			return "#{cmd} does not support ws-create. Make sure you have a supported version (e.g. http://github.com/s3tools/s3cmd 994f28e)." unless supportsWsCreate

			nil
		end

		# Checks that s3cmd-modified exists, and supports the 'parallel' and 'workers' options
		def validateS3cmdParallel(cmd)
			return "#{cmd} does not exist" unless File.file?(cmd)
			return "#{cmd} is not executable" unless File.executable?(cmd)

			help = `#{cmd} --help`
			supportsParallel = help.index("--parallel") != nil
			supportsWorkers = help.index("--workers") != nil
			return "#{cmd} does not support --parallel. Make sure you have a supported version (e.g. http://github.com/cdre/s3cmd-modification 39d6b99)." unless supportsParallel

			nil
		end

		# Checks that the git repository exists, is really a git repo and has at least one remote
		def validateRepository(repo)
			gitPath = File.join(repo, ".git")
			return "#{repo} does not appear to exist." unless File.directory?(repo)
			return "#{repo} does not appear to be a git repository." unless File.directory?(gitPath)

			remotes = `(cd #{repo} ; git remote)`.split('\n')
			return "#{repo} does not have any remotes" unless remotes.length > 0
			return "#{repo} does not appear to be a valid git repository." if remotes[0].start_with?("fatal: Not a git repository")

			nil
		end

		# Test a configuration file to ensure validity
		def validateConfig(config)
			issues = [] # String description of every issue we find in the config validation process

			options = {
				# AWS API key used for accessing Route 53
				#  'AKIAASAJIU8SD23JEXA2'
				"route53_aws_api" => {
					:mandatory => true,
				},

				# AWS secret used for accessing Route 53
				#  'SD33FUTYYXD+eDJSDIJjdsIOS32opsd0sd34/RdT'
				"route53_aws_secret" => {
					:mandatory => true,
				},

				# AWS API key used for accessing S3
				#  'AKIAASAJIU8SD23JEXA2'
				"s3_aws_api" => {
					:mandatory => true,
				},

				# AWS secret used for accessing S3
				#  'SD33FUTYYXD+eDJSDIJjdsIOS32opsd0sd34/RdT'
				"s3_aws_secret" => {
					:mandatory => true,
				},

				# Region used for Amazon S3
				#  'us-east-1'
				"s3_region" => {
					:default => "us-east-1",
					:validate => lambda { |region| validateS3Region(region) },
				},

				# Path to modified s3cmd supporting parallel worker threads
				#  '/home/user/s3cmd-modification/s3cmd'
				"s3cmd_parallel" => {
					:mandatory => true,
					:validate => lambda { |cmd| validateS3cmdParallel(cmd) },
				},

				# Number of worker threads to run in parallel
				#  '30'
				"s3cmd_parallel_workers" => {
					:default => 30,
					:transform => lambda { |workers| workers.is_a?(String) ? workers.to_i : worker }
				},

				# Absolute path to s3cmd script supporting newer commands like ws-create
				#  '/home/user/s3cmd/s3cmd'
				"s3cmd" => {
					:mandatory => true,
					:validate => lambda { |cmd| validateS3cmd(cmd) },
				},

				# Port number to listen on for HTTP WebHook requests.
				#  '3310'
				"http_port" => {
					:default => 3310,
					:transform => lambda { |port| port.is_a?(String) ? port.to_i : port }
				}
			}

			# First iterate through and ensure we validate every key is set
			options.each_pair do |key, requirements|
				if config.params.has_key?(key) then
					config.params[key] = requirements[:transform].call(config.params[key]) if requirements.has_key?(:transform)
				else
					if requirements.has_key?(:default) then
						config.params[key] = requirements[:default]
					elsif requirements[:mandatory]
						issues.push("#{key}: Missing configuration parameter #{key} is mandatory")
					end
				end
			end

			# Now that we know every validator can count on every value, call the validators
			options.each_pair do |key, requirements|
				if config.params.has_key?(key) and requirements.has_key?(:validate) then
					validators = requirements[:validate]
					validators = [ validators ] if validators.is_a?(Proc)

					validators.each do |v|
						issue = v.call(config[key])
						issues.push("#{key}: #{issue}") unless issue.nil?
					end
				end
			end

			if issues.length > 0 then
				@@log.fatal("Invalid configuration (#{issues.length} issues)\n\t#{issues.join("\n\t")}")
			end
			
			issues.length == 0
		end

		# Loads in the configuration file, validating and setting defaults as needed.
		def setupConfig(configFile)
			puts "Loading config #{configFile}"
			@config = ParseConfig.new(configFile)
			unless validateConfig(@config)
				@@log.fatal("Terminating due to configuration problems")
				exit 1
			end

			@@log.debug("Validated config\nContents: #{@config.params.to_s}")
		end

		def params
			return @config.params
		end

		# Convenience accessor for config parameters
		def [](param)
			return @config[param]
		end
	end
end
