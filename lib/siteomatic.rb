require 'json'
require 'logger'
require 'parseconfig'
require 'route53'
require 'sinatra'
require 'rest-client'
require 'twilio-ruby'
require 'uri'

require 'siteomatic/s3manager'
require 'siteomatic/repositorymanager'
require 'siteomatic/dnsmanager'
require 'siteomatic/hostconfig'
require 'siteomatic/site'
require 'siteomatic/webhooklistener'
require 'siteomatic/emailnotifier'
require 'siteomatic/textnotifier'

module Siteomatic

	# Acts as the frontend for the Siteomatic utility.
	class Siteomatic
		attr_reader :hostConfig, :s3Manager, :sites, :textNotifier, :emailNotifier

		@@siteomatic = nil
		@@log = Logger.new(STDOUT)
		@@log.level = Logger::DEBUG

		# Convenience accessor to the Logger instance.
		def self.log
			@@log
		end

		# Accessor for singleton siteomatic instance
		def self.siteomatic
			@@siteomatic
		end

		# Initializes a Siteomatic instance from host configuration and site configuration files.
		def initialize(hostConfigFile, siteConfigFile)
			@hostConfig = HostConfig.new(hostConfigFile)
			@s3Manager = S3Manager.new(@hostConfig["s3_aws_api"],
				@hostConfig["s3_aws_secret"],
				@hostConfig["s3cmd"],
				@hostConfig["s3cmd_parallel"],
				@hostConfig["s3cmd_parallel_workers"],
				@hostConfig["s3_region"])
			
			begin
				siteList = JSON.parse(File.read(siteConfigFile))
			rescue JSON::ParserError
				@@log.fatal("Unable to parse #{siteConfigFile}")
				exit 1
			end

			@sites = {}
			siteList.each do |site|
				@@log.debug("#{site['url']} -> #{site['directory']}")
				@sites[site["url"]] = Site.new(site, self)
			end

			@textNotifier = TextNotifier.new(self)
			@emailNotifier = EmailNotifier.new(self)
			@@siteomatic = self
		end

		# Updates a single site, identified by URL.
		def updateSite(url)
			@sites[url].syncBranches if @sites.has_key?(url)
		end

		# Updates all sites tracked by this Siteomatic instance.
		def updateAllSites()
			@sites.each_key do |url|
				updateSite(url)
			end
		end

		# Listens for webhook traffic on HTTP
		def listenForWebHook()
			@@log.info("Listening for webhook requests on #{@hostConfig['http_port']}")
			WebHookListener.run!( {:port => @hostConfig['http_port']} )

			# note: WebHookListener.run! blocks
		end
	end
end
