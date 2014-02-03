module Siteomatic
	class S3Manager
		attr_reader :region
		attr_reader :endpoint
		attr_reader :zoneApex

		def self.infoForRegion(region)
			s3info = {
				"us-east-1" => {
					:endpoint => "s3-website-us-east-1.amazonaws.com",
					:zone => "Z3AQBSTGFYJSTF",
				},
				"us-west-1" => {
					:endpoint => "s3-website-us-west-1.amazonaws.com",
					:zone => "Z2F56UZL2M1ACD",
				},
				"us-west-2" => {
					:endpoint => "s3-website-us-west-2.amazonaws.com",
					:zone => "Z3BJ6K6RIION7M",
				},
				"eu-west-1" => {
					:endpoint => "s3-website-eu-west-1.amazonaws.com",
					:zone => "Z1BKCTXD74EZPE",
				},
				"ap-southeast-1" => {
					:endpoint => "s3-website-ap-southeast-1.amazonaws.com",
					:zone => "Z3O0J2DXBE1FTB",
				},
				"ap-southeast-2" => {
					:endpoint => "s3-website-ap-southeast-2.amazonaws.com",
					:zone => "Z1WCIGYICN2BYD",
				},
				"ap-northeast-1" => {
					:endpoint => "s3-website-ap-northeast-1.amazonaws.com",
					:zone => "Z2M4EHUR26P7ZW",
				},
				"sa-east-1" => {
					:endpoint => "s3-website-sa-east-1.amazonaws.com",
					:zone => "Z7KQH4QJS55SO",
				},
				"gov-west-1" => {
					:endpoint => "s3-website-us-gov-west-1.amazonaws.com",
					:zone => "Z31GFT0UA1I2HV",
				},
			}

			return nil unless s3info.has_key?(region)
			return s3info[region]
		end

		def initialize(apiKey, apiSecret, cmdPath, cmdParallelPath, workers=30, region="us-east-1")
			@@log = Siteomatic::log

			@apiKey = apiKey
			@apiSecret = apiSecret

			@cmdPath = cmdPath
			@cmdParallelPath = cmdParallelPath
			@configFile = File.join(Dir.pwd, ".s3cfg-siteomatic")

			regionInfo = S3Manager.infoForRegion(region)
			@region = region
			@zoneApex = regionInfo[:zone]
			@endpoint = regionInfo[:endpoint]
			@workers = workers

			generateConfig

			@@log.debug("Initialized S3 manager, region=#{@region}, workers=#{@workers}")
		end

		def generateConfig
			template = File.expand_path(File.dirname(__FILE__) + '/../../res/s3cfg-template')
			config = File.read(template)
			config.gsub!(/\$S3_ACCESS_KEY/, @apiKey)
			config.gsub!(/\$S3_SECRET_KEY/, @apiSecret)
			File.open(@configFile, 'w') { |f| f.write(config) }
			@@log.debug("Generated S3 config at #{@configFile}")
			self
		end

		def syncSiteFromDirectory(bucket, directory)
			# Make the bucket in S3 if it doesn't exist already.
			@@log.debug("Making bucket #{bucket}")
			`#{@cmdPath} -c #{@configFile} mb s3://#{bucket}`

			# Mark the site as a static website
			@@log.debug("Marking bucket #{bucket} as static website")
			`#{@cmdPath} -c #{@configFile} ws-create s3://#{bucket}`

			# Upload the site into the S3 bucket
			#  --rr -- Reduced redundancy (i.e. reduced cost)
			#  --acl-public -- Files are world-readable
			#  --exclude=.git* -- Exclude all git files
			#  --delete-removed -- Remove remote files that no longer correspond to local files
			#  --parallel -- Enable parallel transfers
			#  --workers=? -- Number of worker threads to use in parallel transfers
			#
			# Parallel workers uses a forked version of s3cmd, but provide a massive improvement in completion time.
			@@log.debug("Syncing bucket #{bucket}")
			`(cd #{directory} && #{@cmdParallelPath} -c #{@configFile} --rr --acl-public --exclude=.git* --delete-removed --parallel --workers=#{@workers} sync . s3://#{bucket})`
			self
		end
	end
end
