require 'json'
require 'logger'
require 'parseconfig'
require 'route53'
require 'sinatra'
require 'uri'

require 'siteomatic/s3manager'
require 'siteomatic/repositorymanager'
require 'siteomatic/dnsmanager'
require 'siteomatic/hostconfig'
require 'siteomatic/site'

module Siteomatic

	# Acts as the frontend for the Siteomatic utility.
	class Siteomatic
		attr_reader :hostConfig, :s3Manager, :sites

		@@log = Logger.new(STDOUT)
		@@log.level = Logger::DEBUG

		# Convenience accessor to the Logger instance.
		def self.log
			return @@log
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
		end

		# Updates a single site, identified by URL.
		def updateSite(url)
			@sites[url].syncBranches
		end

		# Updates all sites tracked by this Siteomatic instance.
		def updateAllSites()
			@sites.each_key do |url|
				updateSite(url)
			end
		end
	end
end
