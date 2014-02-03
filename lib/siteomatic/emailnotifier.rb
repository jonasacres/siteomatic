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
