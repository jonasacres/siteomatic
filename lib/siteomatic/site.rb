# Siteomatic, a tool for automatically deploying websites
# Copyright (C) 2014  Jonas Acres
# jonas@becuddle.com
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#    
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#    
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

module Siteomatic
	class Site
		def initialize(siteConfig, siteomatic)
			@@log = Siteomatic::log

			@siteomatic = siteomatic
			@siteConfig = siteConfig
			normalizeSiteConfig

			@repoManager = RepositoryManager.new(@siteConfig["directory"])
			@dnsManager = DNSManager.new(@siteomatic.hostConfig["route53_aws_api"],
				@siteomatic.hostConfig["route53_aws_secret"],
				@siteConfig["domain"])
		end

		# Populate implied values in site configuration
		def normalizeSiteConfig
			@siteConfig["default"] ||= {}
			@siteConfig["default"]["update"] = true unless @siteConfig["default"].has_key?("update")
			@siteConfig["default"]["email"] ||= []
			@siteConfig["default"]["text"] ||= []

			@siteConfig["branches"] ||= {}
			@siteConfig["branches"].each_pair do |branch, branchCfg|
				branchCfg["email"] ||= []
				branchCfg["text"] ||= []
				branchCfg["update"] ||= true
			end
		end

		# Gets the branch config for a given branch name
		def branchConfig(branch)
			return @siteConfig["branches"][branch] if @siteConfig["branches"].has_key?(branch)
			return @siteConfig["default"]
		end

		# Filters a branch name so that it is DNS-friendly.
		#   All letters are made lowercase
		#   All non-alphanumeric characters are converted to "-"
		#   Leading and trailing "-" are stripped
		#   Consecutive "-" are squashed to a single "-""
		# e.g. "__EXPERIMENTAL/site37.com-green!""  ->  "experimental-site37-com-green"
		def sanitizeBranch(branch)
			branch.gsub(/[^a-zA-Z0-9-]+/, "-").gsub(/-+/, "-").gsub(/-$/, "").gsub(/^-/, "").downcase
		end

		# Determines the appropriate bucket name for a branch in the configured domain.
		# If the branch is listed in the branchmaps seciton of the configuration, we'll use the hardcoded bucket name.
		# Otherwise, we'll sanitize the branch name and add it as a subdomain of the configured domain, e.g.
		#  branch.domain.com
		def bucketForBranchDomain(branch)
			branchCfg = branchConfig(branch)
			return branchCfg["domain"] if branchCfg.has_key?("domain")
			return "#{sanitizeBranch(branch)}.#{@siteConfig['domain']}"
		end

		# Runs the user-configured script for the branch, if specified.
		def runScript(branch)
			branchCfg = branchConfig(branch)
			`#{branchCfg["script"]}` unless branchCfg["script"].nil?
		end

		# Get the last synchronized commit for a branch
		def syncedCommitForBranch(branch)
			# Get the last synced commit from the TXT record.
			fqdn = bucketForBranchDomain(branch) + "."
			info = @dnsManager.findDNSValue(fqdn, "TXT")
			return nil if info.nil?

			# To be valid, the TXT record must be a hash containing 'commit' and 'branch'
			# keys, and the value of the 'branch' key must match our actual branch.
			return nil unless info.is_a?(Hash)
			return nil unless info.has_key?("branch") && info.has_key?("commit")
			return nil unless info["branch"] == branch

			@@log.debug("Last commit for #{branch} -> #{info['commit']}")
			return info["commit"]
		end

		# Upload a branch into an Amazon S3 bucket and configure the domain alias in Route 53
		def syncBranch(branch)
			branchCfg = branchConfig(branch)
			return false unless branchCfg["update"] # Skip this branch if we're not supposed to update it

			@@log.info("Syncing #{branch}")

			# Our bucket name, which per convention is also our domain name
			bucket = bucketForBranchDomain(branch)

			# Current commit hash for our branch
			info = @repoManager.infoForBranch(branch)
			if info == nil then
				@@log.fatal("No such branch #{branch}")
				return false
			end

			@@log.info("Branch #{branch}, commit #{info[:hash]} by #{info[:committer]}")
			if info[:hash] == syncedCommitForBranch(branch) then
				# This branch is already synced up. No need to duplicate the effort.
				@@log.info("Previously synced #{branch} to commit #{hash}; skipping.")
				return false
			else
				@@log.info("Preparing to sync...")
			end

			# Set up our working directory with the contents of the branch
			@repoManager.checkout(info[:hash])

			# Run user script
			runScript(branch)

			# Upload to S3
			@siteomatic.s3Manager.syncSiteFromDirectory(bucket, directoryForSite)

			# Set the DNS records
			@dnsManager.setRecord(bucket, "A", @siteomatic.s3Manager.endpoint, @siteomatic.s3Manager.zoneApex)
			@dnsManager.setRecord(bucket, "TXT", { :commit => info[:hash], :branch => branch }, nil, 10)

			@@log.info("Synced #{branch} to commit #{info[:hash]}.")

			@siteomatic.textNotifier.notify(branchCfg["text"], "http://#{bucket} updated by #{info[:committer]}")
			@siteomatic.emailNotifier.notify(branchCfg["email"], "http://#{bucket} updated", "http://#{bucket} updated to commit #{info[:hash][0..6]} by #{info[:committer]}.")

			return true
		end

		def directoryForSite
			return File.join(@repoManager.directory, @siteConfig["documentRoot"]) unless @siteConfig["documentRoot"].nil?
			
			@repoManager.directory
		end

		# Updates the repository with the contents of all remotes, then uploads modified branches to S3.
		# Warning: returns repository to a pristine state, discarding all uncommitted local changes, including changes in .gitignore'd
		# files.
		def syncBranches
			@dnsManager.refresh
			@repoManager.clean.update.listBranches.each { |branch| syncBranch(branch) }
		end
	end
end