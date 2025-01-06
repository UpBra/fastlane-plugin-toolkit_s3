# -------------------------------------------------------------------------
#
# S3 Find
# Find a file on S3.
#
# -------------------------------------------------------------------------


module Fastlane

	module Actions

		module SharedValues
			S3_FIND_PUBLIC_URL = :S3_FIND_PUBLIC_URL
		end

		class S3FindAction < Action

			module Keys
				ACCESS_KEY = :ACCESS_KEY
				ACCESS_SECRET = :ACCESS_SECRET
				REGION = :REGION
				BUCKET = :BUCKET
				PREFIX = :PREFIX
				FILENAME = :FILENAME
				FAIL = :FAIL
			end

			def self.run(params)
				require 'aws-sdk-s3'

				access_key = require_property(params[Keys::ACCESS_KEY], 'Missing property :access_key')
				access_secret = require_property(params[Keys::ACCESS_SECRET], 'Missing property :access_secret')
				region = require_property(params[Keys::REGION], 'Missing property :region')
				bucket = require_property(params[Keys::BUCKET], 'Missing property :bucket')
				prefix = require_property(params[Keys::PREFIX], 'Missing property :prefix')
				filename = require_property(params[Keys::FILENAME], 'Missing property :filename')
				fail = params[Keys::FAIL]

				FastlaneCore::PrintTable.print_values(
					config: params,
					title: "Summary for S3 Find",
					mask_keys: [Keys::ACCESS_KEY, Keys::ACCESS_SECRET]
				)

				s3_resource = Aws::S3::Resource.new(region: region, access_key_id: access_key, secret_access_key: access_secret)
				s3_bucket = s3_resource.bucket(bucket)
				s3_objects = s3_bucket.objects(prefix: prefix)
				s3_filtered = s3_objects.select { |n| n.key.include?(filename) }

				if s3_filtered.empty? && fail
					UI.user_error!("No files were found with filename: #{filename}")
				end

				if s3_filtered.count > 1
					UI.important('More than one s3 file was found. Returning the first element which may not be the one you want')
				end

				if (first = s3_filtered.first)
					lane_context[SharedValues::S3_FIND_PUBLIC_URL] = first.public_url
				end
			end

			def self.require_property(arg, message)
				UI.user_error!("#{display_name}: #{message}") if arg.nil? || arg.empty?

				arg
			end

			#####################################################
			# @!group Documentation
			#####################################################

			def self.display_name
				's3_find'
			end

			def self.description
				"A short description with <= 80 characters of what this action does"
			end

			def self.available_options
				[
					FastlaneCore::ConfigItem.new(
						key: Keys::ACCESS_KEY,
						env_name: 'S3_FIND_ACCESS_KEY',
						description: 'AWS Access Key',
						is_string: true,
						optional: true
					),
					FastlaneCore::ConfigItem.new(
						key: Keys::ACCESS_SECRET,
						env_name: 'S3_FIND_ACCESS_SECRET',
						description: 'AWS Access Secret',
						is_string: true,
						optional: true
					),
					FastlaneCore::ConfigItem.new(
						key: Keys::REGION,
						env_name: 'S3_FIND_REGION',
						description: 'Name of the S3 region',
						is_string: true,
						optional: true
					),
					FastlaneCore::ConfigItem.new(
						key: Keys::BUCKET,
						env_name: 'S3_FIND_BUCKET',
						description: 'Name of the S3 bucket',
						is_string: true,
						optional: true
					),
					FastlaneCore::ConfigItem.new(
						key: Keys::PREFIX,
						env_name: 'S3_FIND_PREFIX',
						description: 'prefix - folder path - to search in',
						is_string: true,
						optional: true
					),
					FastlaneCore::ConfigItem.new(
						key: Keys::FILENAME,
						env_name: 'S3_FIND_FILENAME',
						description: 'Name of the file to find',
						is_string: true,
						optional: true
					),
					FastlaneCore::ConfigItem.new(
						key: Keys::FAIL,
						env_name: 'S3_FIND_FAIL',
						description: 'Should the action produce an error if no result is found',
						type: Boolean,
						default_value: false
					)
				]
			end

			def self.output
				[
					['S3_FIND_PUBLIC_URL', 'The public url of the file that was found']
				]
			end

			def self.return_value
				"None"
			end

			def self.authors
				["UpBra"]
			end

			def self.is_supported?(platform)
				true
			end
		end
	end
end
