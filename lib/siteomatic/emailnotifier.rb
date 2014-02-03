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
	class EmailNotifier
		def initialize(siteomatic)
			@@log = Siteomatic.log
			@siteomatic = siteomatic

			@mailgunKey = @siteomatic.hostConfig["mailgun_key"]
			@mailgunDomain = @siteomatic.hostConfig["mailgun_domain"]
			@mailgunFrom = @siteomatic.hostConfig["mailgun_from"]
			@disabled = @mailgunKey.nil? or @mailgunDomain.nil? or @mailgunFrom.nil?
			
			unless @disabled then
				@@log.info("EmailNotifier active as #{@mailgunFrom}")
			end
		end

		def notify(recipients, subject, body)
			return if @disabled

			recipients = [ recipients ] if recipients.is_a?(String)
			return if recipients.length == 0

			@@log.info("Emailing '#{subject}' to #{recipients.join(', ')}")
			url = "https://api:#{@mailgunKey}@api.mailgun.net/v2/#{@mailgunDomain}/messages"
			RestClient.post url,
				:from => @mailgunFrom,
				:to => recipients.join(", "),
				:subject => subject,
				:html => body
		end
	end
end
