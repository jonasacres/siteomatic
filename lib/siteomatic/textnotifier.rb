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
