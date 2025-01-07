# -------------------------------------------------------------------------
#
# S3 Find
# Find a file on S3.
#
# -------------------------------------------------------------------------

require 'aws-sdk-s3'
require 'fastlane/action'
require_relative '../helper/toolkit_s3_helper'

module Fastlane

	module Actions

		module SharedValues
			S3_FIND_PUBLIC_URL = :S3_FIND_PUBLIC_URL
		end

		class S3FindAction < Action

			Helper = Fastlane::Helper::ToolkitS3Helper

			def self.run(params)
				access_key = params[Helper::Keys::ACCESS_KEY]
				access_secret = params[Helper::Keys::ACCESS_SECRET]
				region = params[Helper::Keys::REGION]
				bucket = params[Helper::Keys::BUCKET]
				prefix = params[Helper::Keys::PREFIX]
				filename = params[Helper::Keys::FILENAME]
				fail = params[Helper::Keys::FAIL]

				FastlaneCore::PrintTable.print_values(
					config: params,
					title: "Summary for S3 Find",
					mask_keys: [Helper::Keys::ACCESS_KEY, Helper::Keys::ACCESS_SECRET]
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
					UI.success("Found file at #{first.public_url}")
					lane_context[SharedValues::S3_FIND_PUBLIC_URL] = first.public_url
				end
			end

			#####################################################
			# @!group Documentation
			#####################################################

			def self.display_name
				"s3_find"
			end

			def self.description
				"A short description with <= 80 characters of what this action does"
			end

			def self.available_options
				[
					FastlaneCore::ConfigItem.new(
						key: Helper::Keys::ACCESS_KEY,
						env_name: 'S3_FIND_ACCESS_KEY',
						description: 'AWS Access Key',
						type: String,
						optional: false
					),
					FastlaneCore::ConfigItem.new(
						key: Helper::Keys::ACCESS_SECRET,
						env_name: 'S3_FIND_ACCESS_SECRET',
						description: 'AWS Access Secret',
						type: String,
						optional: false
					),
					FastlaneCore::ConfigItem.new(
						key: Helper::Keys::REGION,
						env_name: 'S3_FIND_REGION',
						description: 'Name of the S3 region',
						type: String,
						optional: false
					),
					FastlaneCore::ConfigItem.new(
						key: Helper::Keys::BUCKET,
						env_name: 'S3_FIND_BUCKET',
						description: 'Name of the S3 bucket',
						type: String,
						optional: false
					),
					FastlaneCore::ConfigItem.new(
						key: Helper::Keys::PREFIX,
						env_name: 'S3_FIND_PREFIX',
						description: 'prefix - folder path - to search in',
						type: String,
						optional: true
					),
					FastlaneCore::ConfigItem.new(
						key: Helper::Keys::FILENAME,
						env_name: 'S3_FIND_FILENAME',
						description: 'Name of the file to find',
						type: String,
						optional: false
					),
					FastlaneCore::ConfigItem.new(
						key: Helper::Keys::FAIL,
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
