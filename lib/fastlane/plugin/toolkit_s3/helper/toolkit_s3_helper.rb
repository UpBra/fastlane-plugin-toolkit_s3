require 'fastlane_core/ui/ui'

module Fastlane

	UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

	module Helper

		class ToolkitS3Helper

			module Keys
				ACCESS_KEY = :access_key
				ACCESS_SECRET = :access_secret
				REGION = :region
				BUCKET = :bucket
				ACL = :acl
				FOLDER = :folder
				FILE = :file
				PATH = :path
				CLEAN = :clean
				THREADS = :threads
				DRY_RUN = :dry_run
				PREFIX = :prefix
				FILENAME = :filename
				FAIL = :fail
			end

			def self.message(message)
				UI.message(message)
			end

			def self.verbose(message)
				UI.verbose(message)
			end

			def self.success(message)
				UI.success(message)
			end

			def self.require_property(action, arg, message)
				UI.user_error!("#{action.action_name}: #{message}") if arg.nil? || arg.empty?
			end

			def self.mime_type(file)
				result = `file --brief --mime-type "#{file}"`.strip

				case File.extname(file)
				when '.css'
					result = 'text/css'
				when '.js'
					result = 'text/javascript'
				end

				return result
			end
		end
	end
end
