module Siteomatic
	class WebHookListener < Sinatra::Base
		post '/webhook' do
			contents = JSON.parse(URI.decode(params['payload']))
			url = contents["repository"]["url"]

			logger.info("Received webhook notification for #{url}")
			Siteomatic::siteomatic.updateSite(contents["repository"]["url"])

			"ok thanks\n"
		end
	end
end
