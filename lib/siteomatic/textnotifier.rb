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
	class TextNotifier
		def initialize(siteomatic)
			@@log = Siteomatic::log
			@siteomatic = siteomatic

			@accountSid = @siteomatic.hostConfig["twilio_sid"]
			@authToken = @siteomatic.hostConfig["twilio_auth"]
			@fromNumber = @siteomatic.hostConfig["twilio_from"]
			@disabled = @accountSid.nil? or @authToken.nil? or @fromToken.nil?
			
			unless @disabled then
				@client = Twilio::REST::Client.new(@accountSid, @authToken)
				@@log.info("TextNotifier active on #{@fromNumber}")
			end
		end

		def notify(numbers, message)
			return if @disabled
			numbers = [ numbers ] unless numbers.is_a?(Array)

			numbers.each do |number|
				@@log.debug("Texting #{number}: '#{message}'")
				@client.account.messages.create(
					:from => @fromNumber,
					:to => number,
					:body => message
				)
			end
		end
	end
end
