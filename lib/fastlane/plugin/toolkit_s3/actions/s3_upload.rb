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
			S3_UPLOAD_PUBLIC_FILE_URL = :S3_UPLOAD_PUBLIC_FILE_URL
			S3_UPLOAD_PUBLIC_FOLDER_URL = :S3_UPLOAD_PUBLIC_FOLDER_URL
		end

		class S3UploadAction < Action

			Helper = Fastlane::Helper::ToolkitS3Helper

			def self.run(params)
				FastlaneCore::PrintTable.print_values(
					config: params,
					title: "Summary for s3_upload",
					mask_keys: [Helper::Keys::ACCESS_KEY, Helper::Keys::ACCESS_SECRET]
				)

				file_action(params) if params[Helper::Keys::FILE]
				folder_action(params) if params[Helper::Keys::FOLDER]
			end

			def self.file_action(params)
				access_key = params[Helper::Keys::ACCESS_KEY]
				access_secret = params[Helper::Keys::ACCESS_SECRET]
				region = params[Helper::Keys::REGION]
				bucket = params[Helper::Keys::BUCKET]
				remote_path = params[Helper::Keys::PATH]
				path_to_file = File.expand_path(params[Helper::Keys::FILE])
				dry_run = params[Helper::Keys::DRY_RUN]
				filename = path_to_file.split('/').last

				resource = Aws::S3::Resource.new(region: region, access_key_id: access_key, secret_access_key: access_secret)
				remote_item_path = "#{remote_path}/#{filename}"
				object = resource.bucket(bucket).object(remote_item_path)

				Helper.message("Uploading #{filename} to #{object.public_url}...")

				unless dry_run
					result = object.upload_file(path_to_file)

					UI.user_error!("Failed to upload file to s3") unless result

					lane_context[SharedValues::S3_UPLOAD_PUBLIC_FILE_URL] = object.public_url
				end

				Helper.success("Uploaded #{filename} to #{object.public_url}")

				return true
			end

			def self.folder_action(params)
				access_key = params[Helper::Keys::ACCESS_KEY]
				access_secret = params[Helper::Keys::ACCESS_SECRET]
				region = params[Helper::Keys::REGION]
				bucket = params[Helper::Keys::BUCKET]
				folder = File.expand_path(params[Helper::Keys::FOLDER])
				remote_path = params[Helper::Keys::PATH]
				dry = params[Helper::Keys::DRY_RUN]

				files = Dir.glob("#{folder}/**/*")
				folder_name = folder.split('/').last
				total_files = files.length
				s3_connection = Aws::S3::Resource.new(region: region, access_key_id: access_key, secret_access_key: access_secret)
				s3_bucket = s3_connection.bucket(bucket)
				s3_acl = params[Helper::Keys::ACL]
				file_number = 0
				thread_count = params[Helper::Keys::THREADS]
				threads = []
				mutex = Mutex.new

				Helper.message("Total files: #{total_files}")
				Helper.message("Thread Count: #{thread_count}")

				public_url = s3_bucket.object("#{remote_path}/#{folder_name}").public_url

				thread_count.times do |i|
					threads[i] = Thread.new do
						until files.empty?

							file = nil

							mutex.synchronize do
								file_number += 1
								file = files.pop
								Thread.current['file_number'] = file_number
							end

							next unless file

							file_path = file.sub(%r{^#{folder}/}, "#{folder_name}/")
							path = "#{remote_path}/#{file_path}".gsub("//", "/")
							data = File.open(file)

							Helper.message("[#{Thread.current['file_number']}/#{total_files}] is a directory") if File.directory?(data)

							unless File.directory?(data)
								obj = s3_bucket.object(path)
								content_type = Helper.mime_type(file)

								Helper.message("[#{Thread.current['file_number']}/#{total_files}] uploading #{path} #{content_type}")
								obj.put({ acl: s3_acl.to_s, body: data, content_type: content_type }) unless dry
							end

							data.close
						end
					end
				end

				threads.each(&:join)

				public_url = s3_bucket.object("#{remote_path}/#{folder_name}").public_url
				Helper.success("Uploaded #{folder} to S3 #{bucket}")
				Helper.success("Public URL: #{public_url}")

				lane_context[SharedValues::S3_UPLOAD_PUBLIC_FOLDER_URL] = public_url

				return true
			end

			def self.sync_action(params)
				access_key = params[Helper::Keys::ACCESS_KEY]
				access_secret = params[Helper::Keys::ACCESS_SECRET]
				region = params[Helper::Keys::REGION]
				bucket = params[Helper::Keys::BUCKET]
				local_path = params[Helper::Keys::SYNC]
				remote_path = params[Helper::Keys::PATH]
				s3_connection = Aws::S3::Resource.new(region: region, access_key_id: access_key, secret_access_key: access_secret)

				Dir.glob("#{local_path}/**/*").each do |file|
					next if File.directory?(file)

					s3_key = "#{remote_path}/#{file.sub("#{local_path}/", '')}"
					obj = s3_connection.bucket(bucket).object(s3_key)

					# Upload the file
					obj.upload_file(file)
					puts "Uploaded #{file} to s3://#{bucket}/#{s3_key}"
				end
			end

			#####################################################
			# @!group Documentation
			#####################################################

			def self.display_name
				"s3_publish"
			end

			def self.description
				"S3 implementations to upload a file or a folder to an s3 bucket."
			end

			def self.available_options
				[
					FastlaneCore::ConfigItem.new(
						key: Helper::Keys::ACCESS_KEY,
						env_name: 'S3_UPLOAD_ACCESS_KEY',
						description: 'AWS Access Key',
						optional: false,
						type: String
					),
					FastlaneCore::ConfigItem.new(
						key: Helper::Keys::ACCESS_SECRET,
						env_name: 'S3_UPLOAD_ACCESS_SECRET',
						description: 'AWS Access Secret',
						optional: false,
						type: String
					),
					FastlaneCore::ConfigItem.new(
						key: Helper::Keys::REGION,
						env_name: 'S3_UPLOAD_REGION',
						description: 'Name of the S3 region',
						optional: false,
						type: String
					),
					FastlaneCore::ConfigItem.new(
						key: Helper::Keys::BUCKET,
						env_name: 'S3_UPLOAD_BUCKET',
						description: 'Name of the S3 bucket',
						optional: false,
						type: String
					),
					FastlaneCore::ConfigItem.new(
						key: Helper::Keys::ACL,
						env_name: 'S3_UPLOAD_ACL',
						description: 'ACL permissions. Accepts private, public-read, public-read-write, authenticated-read, aws-exec-read, bucket-owner-read, bucket-owner-full-control',
						type: String,
						default_value: 'public-read'
					),
					FastlaneCore::ConfigItem.new(
						key: Helper::Keys::FILE,
						env_name: 'S3_UPLOAD_FILE',
						description: 'The file to upload',
						optional: true,
						type: String
					),
					FastlaneCore::ConfigItem.new(
						key: Helper::Keys::FOLDER,
						env_name: 'S3_UPLOAD_FOLDER',
						description: 'The folder to upload',
						optional: true,
						type: String
					),
					FastlaneCore::ConfigItem.new(
						key: Helper::Keys::PATH,
						env_name: 'S3_UPLOAD_PATH',
						description: 'The remote path to upload files. Applies to :file and :folder parameters',
						optional: false,
						type: String
					),
					FastlaneCore::ConfigItem.new(
						key: Helper::Keys::THREADS,
						env_name: 'S3_UPLOAD_THREADS',
						description: 'Count of threads',
						is_string: false,
						default_value: 3
					),
					FastlaneCore::ConfigItem.new(
						key: Helper::Keys::DRY_RUN,
						env_name: 'S3_UPLOAD_DRY_RUN',
						description: 'Toggle dry run',
						is_string: false,
						default_value: false
					),
					FastlaneCore::ConfigItem.new(
						key: Helper::Keys::SYNC,
						env_name: 'S3_UPLOAD_SYNC',
						description: 'Is folder action a sync?',
						is_string: false,
						default_value: false
					)
				]
			end

			def self.output
				[
					['S3_UPLOAD_PUBLIC_FILE_URL', 'The public url of the :file that was uploaded.'],
					['S3_UPLOAD_PUBLIC_FOLDER_URL', 'The public url of the :folder that was uploaded.']
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
'# Upload just a file
s3_publish(
	access_key: "aws access key",
	access_secret: "aws access secret",
	region: "us-east-1",
	bucket: "de-builds-staging",
	file: "path/to/file.app",
	path: "remote/path" # file is copied into this folder
)',
'# Upload a folder
s3_publish(
	access_key: "aws access key",
	access_secret: "aws access secret",
	region: "us-east-1",
	bucket: "de-builds-staging",
	folder: "path/to/folder",
	path: "remote/path" # folder is copied into this path
)'
				]
			end

			def self.is_supported?(platform)
				true
			end
		end
	end
end
