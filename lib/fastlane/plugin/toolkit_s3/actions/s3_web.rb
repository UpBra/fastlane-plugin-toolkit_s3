# -------------------------------------------------------------------------
#
# S3 Web
# Deploys a web folder to S3.
#
# -------------------------------------------------------------------------

require 'aws-sdk-s3'
require 'fastlane/action'
require_relative '../helper/toolkit_s3_helper'

module Fastlane

	module Actions

		module SharedValues
			S3_WEB_PUBLIC_URL = :S3_WEB_PUBLIC_URL
		end

		class S3WebAction < Action

			Helper = Fastlane::Helper::ToolkitS3Helper

			def self.run(params)
				aws_key = params[Helper::Keys::ACCESS_KEY]
				aws_secret = params[Helper::Keys::ACCESS_SECRET]
				region = params[Helper::Keys::REGION]
				bucket = params[Helper::Keys::BUCKET]
				folder_path = params[Helper::Keys::FOLDER]
				thread_count = params[Helper::Keys::THREADS]
				dry_run = params[Helper::Keys::DRY_RUN]
				clean = params[Helper::Keys::CLEAN]

				FastlaneCore::PrintTable.print_values(
					config: params,
					title: "Summary for s3_web",
					mask_keys: [Helper::Keys::ACCESS_KEY, Helper::Keys::ACCESS_SECRET]
				)

				files = Dir.glob("#{folder_path}/**/*")
				total_files = files.length
				connection = Aws::S3::Resource.new(region: region, access_key_id: aws_key, secret_access_key: aws_secret)
				s3_bucket = connection.bucket(bucket)
				file_number = 0
				mutex = Mutex.new
				threads = []

				if clean
					Helper.message("Removing files on #{bucket}...")
					s3_bucket.objects.batch_delete! unless dry_run
					Helper.message("#{bucket} cleared.")
				end

				Helper.message("Total files: #{total_files}")
				Helper.message("Thread Count: #{thread_count}")

				thread_count.times do |i|
					threads[i] = Thread.new do
						until files.empty?
							file = nil

							mutex.synchronize do
								file = files.pop
								file_number += 1
								Thread.current['file_number'] = file_number
							end

							next unless file

							path = file.sub(%r{^#{folder_path}/}, '')
							data = File.open(file)

							unless File.directory?(data)
								obj = s3_bucket.object(path)
								content_type = Helper.mime_type(file)

								UI.message("[#{Thread.current['file_number']}/#{total_files}] uploading #{path} #{content_type}")
								obj.put({ acl: "public-read", body: data, content_type: content_type }) unless dry_run
							end

							data.close
						end
					end
				end

				threads.each(&:join)

				Helper.message(s3_bucket.url)

				lane_context[SharedValues::S3_WEB_PUBLIC_URL] = s3_bucket.url
			end

			#####################################################
			# @!group Documentation
			#####################################################

			def self.description
				'Deploys the contents of a folder as a website to S3'
			end

			def self.available_options
				[
					FastlaneCore::ConfigItem.new(
						key: Helper::Keys::ACCESS_KEY,
						env_name: 'S3_WEB_ACCESS_KEY',
						description: 'AWS Access Key',
						type: String,
						optional: false
					),
					FastlaneCore::ConfigItem.new(
						key: Helper::Keys::ACCESS_SECRET,
						env_name: 'S3_WEB_ACCESS_SECRET',
						description: 'AWS Access Secret',
						type: String,
						optional: false
					),
					FastlaneCore::ConfigItem.new(
						key: Helper::Keys::REGION,
						env_name: 'S3_WEB_REGION',
						description: 'Name of the S3 bucket',
						type: String,
						optional: false
					),
					FastlaneCore::ConfigItem.new(
						key: Helper::Keys::BUCKET,
						env_name: 'S3_WEB_BUCKET',
						description: 'Name of the S3 bucket',
						type: String,
						optional: false
					),
					FastlaneCore::ConfigItem.new(
						key: Helper::Keys::FOLDER,
						env_name: 'S3_WEB_FOLDER',
						description: 'The folder to upload',
						type: String,
						optional: false
					),
					FastlaneCore::ConfigItem.new(
						key: Helper::Keys::CLEAN,
						env_name: 'S3_UPLOAD_CLEAN',
						description: 'If the web folder action should clean the s3 bucket',
						type: Boolean,
						default_value: false
					),
					FastlaneCore::ConfigItem.new(
						key: Helper::Keys::THREADS,
						env_name: 'S3_WEB_THREADS',
						description: 'Count of threads',
						type: Integer,
						default_value: 3
					),
					FastlaneCore::ConfigItem.new(
						key: Helper::Keys::DRY_RUN,
						env_name: 'S3_WEB_DRY_RUN',
						description: 'Toggle dry run',
						type: Boolean,
						default_value: false
					)
				]
			end

			def self.output
				[]
			end

			def self.return_value
				"Returns the website url"
			end

			def self.authors
				["UpBra"]
			end

			def self.example_code
				[
's3_web(
	access_key: ENV["AWS_ACCESS_KEY"],
	access_secret: ENV["AWS_ACCESS_SECRET"],
	region: "us-east-1",
	bucket: "my-bucket",
	folder: "path/to/folder"
)'
				]
			end

			def self.is_supported?(platform)
				true
			end
		end
	end
end
