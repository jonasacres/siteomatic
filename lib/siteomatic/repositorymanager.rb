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

		# Returns the current commit hash and committer for a branch, or nil if the branch is not found
		def infoForBranch(branch)
			result = `(cd #{@directory} ; git log --pretty=format:"%H %ce" -n 1 origin/#{branch})`
			return nil if result.start_with?("fatal:")

			comps = result.split(' ')
			info = { :committer => comps[1..-1].join(" "), :hash => comps[0] }

			@@log.debug("#{@directory} #{branch} -> #{info[:hash]} by #{info[:committer]}")

			return info
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
