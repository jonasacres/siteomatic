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
	class WebHookListener < Sinatra::Base
		get '/version' do
			"Siteomatic 1.0.0\n"
		end

		post '/webhook' do
			# Github supplies a non-standard request content-type field to help us figure out
			# if they're supplying a JSON or form-encoded notification.
			contents = case request.env["CONTENT_TYPE"]
			when "application/x-www-form-urlencoded"
				JSON.parse(URI.decode(params['payload']))
			when "application/json"
				JSON.parse(request.body.read)
			else
				JSON.parse(request.body.read)
			end

			url = contents["repository"]["url"]

			logger.info("Received webhook notification for #{url}")
			Siteomatic::siteomatic.updateSite(contents["repository"]["url"])

			"ok thanks\n"
		end
	end
end
