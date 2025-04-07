# -------------------------------------------------------------------------
#
# S3 Upload
# Action to upload files or folders to s3.
#
# -------------------------------------------------------------------------

require 'aws-sdk-s3'
require 'fastlane/action'
require_relative '../helper/toolkit_s3_helper'

module Fastlane

	module Actions

		module SharedValues
			S3_SYNC_REMOTE_URL = :S3_SYNC_REMOTE_URL
		end

		class S3SyncAction < Action

			Helper = Fastlane::Helper::ToolkitS3Helper

			def self.run(params)
				FastlaneCore::PrintTable.print_values(
					config: params,
					title: "Summary for s3_sync",
					mask_keys: [Helper::Keys::ACCESS_KEY, Helper::Keys::ACCESS_SECRET]
				)

				local_folder = File.expand_path(params[Helper::Keys::LOCAL])
				files = Dir.glob("#{local_folder}/**/*").select { |file| File.file?(file) }
				moves = files.map do |file|
					file_path = file.sub(local_folder, "")
					remote_path = params[Helper::Keys::REMOTE] + file_path
					Helper::Move.new(file, remote_path)
				end

				s3_bucket = Helper.transfer(moves, params)
				public_url = s3_bucket.object(params[Helper::Keys::REMOTE]).public_url

				Helper.success("Public URL: #{public_url}")

				lane_context[SharedValues::S3_SYNC_FOLDER_URL] = public_url
			end

			#####################################################
			# @!group Documentation
			#####################################################

			def self.display_name
				"s3_sync"
			end

			def self.description
				"S3 implementations to sync a local and remote folder."
			end

			def self.available_options
				[
					FastlaneCore::ConfigItem.new(
						key: Helper::Keys::ACCESS_KEY,
						env_name: 'S3_SYNC_ACCESS_KEY',
						description: 'AWS Access Key',
						optional: false,
						type: String
					),
					FastlaneCore::ConfigItem.new(
						key: Helper::Keys::ACCESS_SECRET,
						env_name: 'S3_SYNC_ACCESS_SECRET',
						description: 'AWS Access Secret',
						optional: false,
						type: String
					),
					FastlaneCore::ConfigItem.new(
						key: Helper::Keys::REGION,
						env_name: 'S3_SYNC_REGION',
						description: 'Name of the S3 region',
						optional: false,
						type: String
					),
					FastlaneCore::ConfigItem.new(
						key: Helper::Keys::BUCKET,
						env_name: 'S3_SYNC_BUCKET',
						description: 'Name of the S3 bucket',
						optional: false,
						type: String
					),
					FastlaneCore::ConfigItem.new(
						key: Helper::Keys::ACL,
						env_name: 'S3_SYNC_ACL',
						description: 'ACL permissions. Accepts private, public-read, public-read-write, authenticated-read, aws-exec-read, bucket-owner-read, bucket-owner-full-control',
						type: String,
						default_value: 'public-read'
					),
					FastlaneCore::ConfigItem.new(
						key: Helper::Keys::LOCAL,
						env_name: 'S3_SYNC_LOCAL',
						description: 'The local folder to sync',
						optional: true,
						type: String
					),
					FastlaneCore::ConfigItem.new(
						key: Helper::Keys::REMOTE,
						env_name: 'S3_SYNC_REMOTE_FOLDER',
						description: 'The remote folder to sync',
						optional: false,
						type: String
					),
					FastlaneCore::ConfigItem.new(
						key: Helper::Keys::THREADS,
						env_name: 'S3_SYNC_THREADS',
						description: 'Count of threads',
						is_string: false,
						default_value: 3
					),
					FastlaneCore::ConfigItem.new(
						key: Helper::Keys::DRY_RUN,
						env_name: 'S3_SYNC_DRY_RUN',
						description: 'Toggle dry run',
						is_string: false,
						default_value: false
					)
				]
			end

			def self.output
				[
					['S3_SYNC_REMOTE_URL', 'The public url of the remote folder that was synced']
				]
			end

			def self.return_value
				nil
			end

			def self.authors
				["UpBra"]
			end

			def self.example_code
				[
'# Sync
s3_sync(
	access_key: "aws access key",
	access_secret: "aws access secret",
	region: "us-east-1",
	bucket: "bucket-name",
	local: "folder/to/sync",
	remote: "remote/folder/to/sync" # file is copied into this folder
)'
				]
			end

			def self.is_supported?(platform)
				true
			end
		end
	end
end
