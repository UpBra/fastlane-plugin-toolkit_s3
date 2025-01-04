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
				AccessKey = :access_key
				AccessSecret = :access_secret
				Region = :region
				Bucket = :bucket
				Prefix = :prefix
				Filename = :filename
				Fail = :fail
			end

			def self.run(params)
				require 'aws-sdk-s3'

				access_key = require_property(params[Keys::AccessKey], 'Missing property access key')
				access_secret = require_property(params[Keys::AccessSecret], 'Missing property access secret')
				region = require_property(params[Keys::Region], 'Missing property region')
				bucket = require_property(params[Keys::Bucket], 'Missing property bucket')
				prefix = require_property(params[Keys::Prefix], 'Missing property prefix')
				filename = require_property(params[Keys::Filename], 'Missing property filename')
				fail = params[Keys::Fail]

				FastlaneCore::PrintTable.print_values(
					config: params,
					title: "Summary for S3 Find",
					mask_keys: [Keys::AccessKey, Keys::AccessSecret]
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
						key: Keys::AccessKey,
						env_name: 'S3_FIND_ACCESS_KEY',
						description: 'AWS Access Key',
						is_string: true,
						optional: true
					),
					FastlaneCore::ConfigItem.new(
						key: Keys::AccessSecret,
						env_name: 'S3_FIND_ACCESS_SECRET',
						description: 'AWS Access Secret',
						is_string: true,
						optional: true
					),
					FastlaneCore::ConfigItem.new(
						key: Keys::Region,
						env_name: 'S3_FIND_REGION',
						description: 'Name of the S3 region',
						is_string: true,
						optional: true
					),
					FastlaneCore::ConfigItem.new(
						key: Keys::Bucket,
						env_name: 'S3_FIND_BUCKET',
						description: 'Name of the S3 bucket',
						is_string: true,
						optional: true
					),
					FastlaneCore::ConfigItem.new(
						key: Keys::Prefix,
						env_name: 'S3_FIND_PREFIX',
						description: 'Prefix - folder path - to search in',
						is_string: true,
						optional: true
					),
					FastlaneCore::ConfigItem.new(
						key: Keys::Filename,
						env_name: 'S3_FIND_FILENAME',
						description: 'Name of the file to find',
						is_string: true,
						optional: true
					),
					FastlaneCore::ConfigItem.new(
						key: Keys::Fail,
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
