module Siteomatic
	class RepositoryManager
		attr_reader :directory

		def initialize(directory)
			@@log = Siteomatic::log
			@directory = directory
		end

		# Resets the repository to a pristine state, discarding ALL unsaved changes.
		def clean
			@@log.debug("Cleaning repository #{@directory}")
			`(cd #{@directory} ; git reset --hard)` # Revert changes to tracked files
			`(cd #{@directory} ; git clean -dxf)` # Discard untracked and ignored files and directories
			self
		end

		# Grab new commits from the remote
		def update
			@@log.debug("Updating repository #{@directory}")
			# Sync with all remotes, pruning tracking branches that no longer exist, and be quiet about it
			`(cd #{@directory} ; git fetch --all -pq)`
			self
		end

		# Checks out the working directory for a branch (or commit hash)
		def checkout(branch)
			@@log.debug("Checking out #{branch} in #{@directory}")
			`(cd #{@directory} ; git checkout #{branch})`
			self
		end

		# Returns the current commit hash for a branch, or nil if the branch is not found
		def commitForBranch(branch)
			hash = `(cd #{@directory} ; git log --pretty=format:"%H" -n 1 origin/#{branch})`
			return nil if hash.start_with?("fatal:")

			@@log.debug("#{@directory} #{branch} -> #{hash}")
			return hash
		end

		# Returns a list of all branches in the repository, including remote branches
		def listBranches
			elements = `(cd #{@directory} ; git branch -r)`.split("\n")
			branches = []
			elements.each do |line|
				branch = line.lstrip.sub("origin/", "")

				# Output contains an entry for HEAD which is irrelevant to us
				branches.push(branch) unless branch.match(/^HEAD ->/)
			end

			@@log.debug("#{@directory} branches: #{branches.join(', ')}")

			return branches
		end
	end
end