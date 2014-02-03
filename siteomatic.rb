#!/usr/bin/ruby

require 'parseconfig'
require 'route53'
require 'sinatra'

def validateConfig(config)
	hasIssues = false
	keys = [ "aws_api", "aws_secret", "s3_endpoint", "s3_zone", "s3cmd_parallel", "s3cmd", "domain", "branchcache", "repository" ]
	keys.each do |key|
		unless config.params.has_key?(key)
			hasIssues = true
			puts "No #{key} in config"
		end
	end

	return !hasIssues
end

def listCurrentBranches
	`git reset --hard`
	`git clean -dxf`
	`git fetch --all -pf`

	elements = `git branch -r`.split("\n")
	branches = []
	elements.each do |line|
		branch = line.lstrip.sub("origin/", "")
		branches.push(branch) unless branch.match(/^HEAD ->/)
	end

	return branches
end

def sanitizeBranch(branch)
	branch.gsub(/[^a-zA-Z0-9-]/, "-").gsub(/-+$/, "").downcase
end

def bucketForBranchDomain(branch)
	if($CONFIG.params.has_key?("branchmaps") && $CONFIG["branchmaps"].has_key?(branch)) then
		return $CONFIG["branchmaps"][branch]
	end

	return "#{sanitizeBranch(branch)}.#{$CONFIG['domain']}"
end

def syncBranch(branch)
	configArg = $CONFIG['s3cmd_config'] ? " -c #{config['s3cmd_config']}" : ""
	workers = $CONFIG['s3cmd_parallel_workers'] || 30 
	bucket = bucketForBranchDomain(branch)
	hash = `git log --pretty=format:"%H" -n 1 origin/#{branch}`
	if $BRANCHCACHE[branch] == hash then
		print "Branch #{branch}\n\tAlready synced to commit #{hash}\n"
		return
	else
		print "Branch #{branch}\n\tSyncing to commit #{hash}\n"
	end

	`git checkout #{branch}`
	`#{$CONFIG['s3cmd_parallel']}#{configArg} mb s3://#{bucket}`
	`#{$CONFIG['s3cmd_parallel']}#{configArg} --acl-public --exclude=.git* sync --parallel --workers=#{workers} . s3://#{bucket}`
	`#{$CONFIG['s3cmd']}#{configArg} ws-create s3://#{bucket}`

	print "\tVerifying DNS for #{bucketForBranchDomain(branch)}\n"
	checkDNS(branch)
	$BRANCHCACHE.add(branch, hash)
	writeBranchCache()
	print "\tSynced\n"
end

def checkDNS(branch)
	recordName = bucketForBranchDomain(branch) + "."
	$ROUTE53_RECORDS.each do |record|
		if record.name == recordName then
			if record.values.length != 1 || record.values[0] != $CONFIG["s3_endpoint"] + "." || record.zone_apex != $CONFIG["s3_zone"] then
				puts "\tUpdating DNS record #{recordName}"
				resp = record.update(nil, nil, nil, [$CONFIG["s3_endpoint"], $CONFIG["s3_zone"]])
			else
				puts "\tDNS record #{recordName} is current"
			end
			return
		end
	end

	puts "\tCreating DNS record #{recordName}"
	newRecord = Route53::DNSRecord.new(recordName, "A", "60", [$CONFIG["s3_endpoint"]], $ROUTE53_ZONE, $CONFIG["s3_zone"])
	resp = newRecord.create
end

def waitForResponse(resp)
	exit 1 if resp.error?
	while resp.pending?
		sleep 0.1
	end
end

def syncBranches
	branches = listCurrentBranches
	branches.each do |branch|
		puts "Syncing #{branch}"
		syncBranch(branch)
	end
end

def writeBranchCache
	file = File.open($CONFIG["branchcache"], 'w')
	$BRANCHCACHE.write(file)
	file.close
end

def setupConfig(argv)
	if argv.length >= 1 then
		configFile = argv[0]
	else
		configFile = "settings.cfg"
	end

	puts "Loading config #{configFile}"
	$CONFIG = ParseConfig.new(configFile)
	unless validateConfig($CONFIG)
		puts "Terminating due to configuration problems"
		return -1
	end

	Dir.chdir($CONFIG["repository"])

	unless File.exist?($CONFIG["branchcache"]) then
		file = File.open($CONFIG["branchcache"], 'w')
		file.close
	end

	$BRANCHCACHE = ParseConfig.new($CONFIG["branchcache"])
end

def setupRoute53
	$ROUTE53_CONN = Route53::Connection.new($CONFIG["aws_api"], $CONFIG["aws_secret"])
	zones = $ROUTE53_CONN.get_zones($CONFIG["domain_zone"])
	$ROUTE53_ZONE = zones.first

	if $ROUTE53_ZONE == nil then
		puts "\tCreating zone #{$CONFIG['domain_zone']}"
		$ROUTE53_ZONE = Route53::Zone.new($CONFIG["domain_zone"], nil, $ROUTE53_CONN)
		resp = $ROUTE53_ZONE.create_zone
	end

	$ROUTE53_RECORDS = $ROUTE53_ZONE.get_records
end



setupConfig(ARGV)
setupRoute53
syncBranches
