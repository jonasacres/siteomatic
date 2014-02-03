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
	class DNSManager
		attr_reader :zoneName

		def initialize(apiKey, apiSecret, zoneName)
			@@log = Siteomatic::log
			components = zoneName.split(".")
			zoneName = "#{components[-2]}.#{components[-1]}" if components.length > 1

			@apiKey = apiKey;
			@apiSecret = apiSecret;
			@zoneName = zoneName;

			@@log.debug("Connecting to Route 53 with key #{@apiKey}, secret #{@apiSecret[0..4]}...")
			@conn = Route53::Connection.new(@apiKey, @apiSecret)
		end

		# Refreshes the zone and record set cache, returning nil if cache cannot be updated
		def refresh
			@records = nil

			@@log.debug("Refreshing zone cache for #{@zoneName}")
			zones = @conn.get_zones(@zoneName)
			return false if zones.nil? || zones.length == 0

			@zone = zones.first
			@@log.debug(@zone)

			@records = @zone.get_records

			@@log.debug(@records)

			return self
		end

		# Lists the cached records, refreshing if none have been cached, returning nil if cache cannot be updated
		def records
			refresh if @records == nil
			return records
		end

		# Finds a cached record of the given FQDN and type, returning nil if no such record exists in cache
		def findDNSRecord(fqdn, type)
			fqdn += '.' unless fqdn.end_with?('.')
			@records.each do |record|
				return record if record.name == fqdn && record.type == type
			end

			return nil
		end

		# Finds the value of a cached record of the given FQDN and type (or nil if not exist), decoding as needed
		# (e.g. TXT records)
		def findDNSValue(fqdn, type)
			record = findDNSRecord(fqdn, type)
			return nil if record.nil?
			return decodeTXT(record.values[0])
		end

		# Updates a DNS record, creating a new one if necessary
		def setRecord(fqdn, type, value, apex=nil, ttl=60)
			fqdn += '.' unless fqdn.end_with?('.')
			value = encodeTXT(value) if type == "TXT"
			
			@@log.debug("Setting #{fqdn} #{type} '#{value}' (apex='#{apex}', TTL=#{ttl})")
			record = findDNSRecord(fqdn, type)
			if record.nil? then
				# Record does not exist
				@@log.info("Creating #{fqdn} #{type} #{value}")
				record = Route53::DNSRecord.new(fqdn, type, "60", [value], @zone, apex)
				record.create
				return self
			end

			if record.values.length != 1 || record.values[0] != value || record.zone_apex != apex then
				# Record exists, but has wrong value or zone apex
				@@log.info("Updating #{fqdn} #{type} #{value}")
				record.update(nil, nil, nil, [value], apex);
				return self
			end

			# Record exists and is correct
			@@log.info("#{fqdn} is current")
			
			return self
		end

		# Encodes a TXT record so it won't confuse Route 53, which requires us to use escaped, quoted strings
		def encodeTXT(value)
			value = JSON.generate(value) unless value.is_a?(String)
			"\"#{URI.encode(value)}\""
		end

		# Decodes a TXT record back to a sensible format
		def decodeTXT(encodedTxt)
			str = URI.decode(encodedTxt[1..-2])
			begin
				return JSON.parse(str)
			rescue JSON::ParserError
				return str
			end
		end
	end
end
