# -------------------------------------------------------------------------
#
# S3 Publish
# Action to publish artifacts to s3.
#
# -------------------------------------------------------------------------

module Fastlane

	module Actions

		module SharedValues
			S3_PUBLISH_PUBLIC_FILE_URL = :S3_PUBLISH_PUBLIC_FILE_URL
			S3_PUBLISH_PUBLIC_FOLDER_URL = :S3_PUBLISH_PUBLIC_FOLDER_URL
			S3_PUBLISH_PUBLIC_WEB_URL = :S3_PUBLISH_PUBLIC_WEB_URL
		end

		class S3PublishAction < Action

			@@verbose = true

			module Keys
				AccessKey = :access_key
				AccessSecret = :access_secret
				Region = :region
				Bucket = :bucket
				ACL = :acl
				Folder = :folder
				File = :file
				Path = :path
				WebFolder = :web_folder
				Clean = :clean
				Threads = :threads
				Verbose = :verbose
				DryRun = :dry_run
			end

			def self.run(params)
				@@verbose = params[Keys::Verbose]

				require_property(params[Keys::AccessKey], 'Missing access key')
				require_property(params[Keys::AccessSecret], 'Missing access secret')
				require_property(params[Keys::Region], 'Missing region')
				require_property(params[Keys::Bucket], 'Missing bucket')

				FastlaneCore::PrintTable.print_values(
					config: params,
					title: "Summary for s3_upload",
					mask_keys: [:access_key, :access_secret]
				)

				file_action(params) if params[Keys::File]
				folder_action(params) if params[Keys::Folder]
				web_action(params) if params[Keys::WebFolder]
			end

			def self.file_action(params)
				accessKey = params[Keys::AccessKey]
				accessSecret = params[Keys::AccessSecret]
				region = params[Keys::Region]
				bucket = params[Keys::Bucket]
				remotePath = params[Keys::Path]
				pathToFile = File.expand_path(params[Keys::File])
				dryRun = params[Keys::DryRun]
				filename = pathToFile.split('/').last

				require_property(accessKey, 'Missing access key')
				require_property(accessSecret, 'Missing access secret')
				require_property(region, 'Missing region')
				require_property(bucket, 'Missing bucket')
				require_property(pathToFile, 'Missing path to local file')

				resource = Aws::S3::Resource.new(region: region, access_key_id: accessKey, secret_access_key: accessSecret)
				remoteItemPath = "#{remotePath}/#{filename}"
				object = resource.bucket(bucket).object(remoteItemPath)

				message("Uploading #{filename} to #{object.public_url}...")

				unless dryRun
					result = object.upload_file(pathToFile)

					UI.user_error!("Failed to upload file to s3") unless result

					lane_context[SharedValues::S3_PUBLISH_PUBLIC_FILE_URL] = object.public_url
				end

				success("Uploaded #{filename} to #{object.public_url}")

				return true
			end

			def self.folder_action(params)
				accessKey = params[Keys::AccessKey]
				accessSecret = params[Keys::AccessSecret]
				region = params[Keys::Region]
				bucket = params[Keys::Bucket]
				folder = File.expand_path(params[Keys::Folder])
				remotePath = params[Keys::Path]
				dry = params[Keys::DryRun]

				require_property(accessKey, 'Missing access key')
				require_property(accessSecret, 'Missing access secret')
				require_property(region, 'Missing region')
				require_property(bucket, 'Missing bucket')
				require_property(folder, 'Missing path to local folder')
				require_property(remotePath, 'Missing remote path')

				files = Dir.glob("#{folder}/**/*")
				folder_name = folder.split('/').last
				total_files = files.length
				s3_connection = Aws::S3::Resource.new(region: region, access_key_id: accessKey, secret_access_key: accessSecret)
				s3_bucket = s3_connection.bucket(bucket)
				s3_acl = params[Keys::ACL]
				file_number = 0
				thread_count = params[Keys::Threads]
				threads = []
				mutex = Mutex.new

				message("Total files: #{total_files}")
				message("Thread Count: #{thread_count}")

				public_url = s3_bucket.object("#{remotePath}/#{folder_name}").public_url

				thread_count.times do |i|
					threads[i] = Thread.new {
						until files.empty?

						mutex.synchronize do
							file_number += 1
							Thread.current['file_number'] = file_number
						end

						file = files.pop rescue nil
							next unless file

							file_path = file.sub(/^#{folder}\//, "#{folder_name}/")
							path = "#{remotePath}/#{file_path}"
							data = File.open(file)

							unless File.directory?(data)
								obj = s3_bucket.object(path)
								content_type = mime_type(file)

								message("[#{Thread.current["file_number"]}/#{total_files}] uploading #{path} #{content_type}")
								obj.put({ acl: "#{s3_acl}", body: data, content_type: content_type }) unless dry
							end

							data.close
						end
					}
				end

				threads.each { |t| t.join }

				success("Uploaded #{folder} to S3 #{bucket}")
				success("Public URL: #{public_url}")

				lane_context[SharedValues::S3_PUBLISH_PUBLIC_FOLDER_URL] = public_url

				return true
			end

			def self.web_action(params)
				accessKey = params[Keys::AccessKey]
				accessSecret = params[Keys::AccessSecret]
				region = params[Keys::Region]
				bucket = params[Keys::Bucket]
				s3_acl = params[Keys::ACL]
				folder = File.expand_path(params[Keys::WebFolder])
				dry = params[Keys::DryRun]
				clean = params[Keys::Clean]

				require_property(accessKey, 'Missing access key')
				require_property(accessSecret, 'Missing access secret')
				require_property(region, 'Missing region')
				require_property(bucket, 'Missing bucket')
				require_property(folder, 'Missing path to local folder')

				files = Dir.glob("#{folder}/**/*")
				total_files = files.length
				s3_connection = Aws::S3::Resource.new(region: region, access_key_id: accessKey, secret_access_key: accessSecret)
				s3_bucket = s3_connection.bucket(bucket)
				file_number = 0
				thread_count = params[Keys::Threads]
				threads = []
				mutex = Mutex.new

				if clean
					message("Removing files on #{bucket}...")
					s3_bucket.objects.batch_delete! unless dry
					message("#{bucket} cleared.")
				end

				message("Total files: #{total_files}")
				message("Thread Count: #{thread_count}")

				thread_count.times do |i|
					threads[i] = Thread.new {
						until files.empty?

						mutex.synchronize do
							file_number += 1
							Thread.current['file_number'] = file_number
						end

						file = files.pop rescue nil
							next unless file

							path = file.sub(/^#{folder}\//, '')
							data = File.open(file)

							unless File.directory?(data)
								obj = s3_bucket.object(path)
								content_type = mime_type(file)

								message("[#{Thread.current["file_number"]}/#{total_files}] uploading #{path} #{content_type}")
								obj.put({ acl: "#{s3_acl}", body: data, content_type: content_type }) unless dry
							end

							data.close
						end
					}
				end

				threads.each { |t| t.join }

				success("Synced #{folder} to S3 #{bucket}")
				success("Public URL: #{s3_bucket.url}")

				lane_context[SharedValues::S3_PUBLISH_PUBLIC_WEB_URL] = s3_bucket.url
			end

			def self.require_property(arg, message)
				UI.user_error!("#{display_name}: #{message}") if arg.nil? || arg.empty?
			end

			def self.message(message)
				UI.message message if @@verbose
			end

			def self.success(message)
				UI.success message
			end

			def self.mime_type(file)
				result = `file --brief --mime-type "#{file}"`.strip

				case File.extname(file)
				when '.css'
					result = 'text/css'
				when '.js'
					result = 'text/javascript'
				else
				end

				return result
			end

			#####################################################
			# @!group Documentation
			#####################################################

			def self.display_name
				's3_publish'
			end

			def self.description
				"S3 implementations to upload a file, folder, or sync a web folder to an s3 bucket."
			end

			def self.available_options
				[
					FastlaneCore::ConfigItem.new(
						key: Keys::AccessKey,
						env_name: 'S3_PUBLISH_ACCESS_KEY',
						description: 'AWS Access Key',
						is_string: true,
						optional: true
					),
					FastlaneCore::ConfigItem.new(
						key: Keys::AccessSecret,
						env_name: 'S3_PUBLISH_ACCESS_SECRET',
						description: 'AWS Access Secret',
						is_string: true,
						optional: true
					),
					FastlaneCore::ConfigItem.new(
						key: Keys::Region,
						env_name: 'S3_PUBLISH_REGION',
						description: 'Name of the S3 region',
						is_string: true,
						optional: true
					),
					FastlaneCore::ConfigItem.new(
						key: Keys::Bucket,
						env_name: 'S3_PUBLISH_BUCKET',
						description: 'Name of the S3 bucket',
						is_string: true,
						optional: true
					),
					FastlaneCore::ConfigItem.new(
						key: Keys::ACL,
						env_name: 'S3_PUBLISH_ACL',
						description: 'ACL permissions. Accepts private, public-read, public-read-write, authenticated-read, aws-exec-read, bucket-owner-read, bucket-owner-full-control',
						is_string: true,
						default_value: 'public-read'
					),
					FastlaneCore::ConfigItem.new(
						key: Keys::Folder,
						env_name: 'S3_PUBLISH_FOLDER',
						description: 'The folder to upload',
						is_string: true,
						optional: true
					),
					FastlaneCore::ConfigItem.new(
						key: Keys::File,
						env_name: 'S3_PUBLISH_FILE',
						description: 'The file to upload',
						is_string: true,
						optional: true
					),
					FastlaneCore::ConfigItem.new(
						key: Keys::Path,
						env_name: 'S3_PUBLISH_PATH',
						description: 'The remote path to upload files. Applies to :file and :folder parameters',
						is_string: true,
						optional: true
					),
					FastlaneCore::ConfigItem.new(
						key: Keys::WebFolder,
						env_name: 'S3_PUBLISH_WEB_FOLDER',
						description: 'The web folder to sync',
						is_string: true,
						optional: true
					),
					FastlaneCore::ConfigItem.new(
						key: Keys::Clean,
						env_name: 'S3_PUBLISH_CLEAN',
						description: 'If the web folder action should clean the s3 bucket',
						is_string: false,
						default_value: false
					),
					FastlaneCore::ConfigItem.new(
						key: Keys::Threads,
						env_name: 'S3_PUBLISH_THREADS',
						description: 'Count of threads',
						is_string: false,
						default_value: 3
					),
					FastlaneCore::ConfigItem.new(
						key: Keys::Verbose,
						env_name: 'S3_PUBLISH_VERBOSE',
						description: 'Toggle verbose output',
						is_string: false,
						default_value: true
					),
					FastlaneCore::ConfigItem.new(
						key: Keys::DryRun,
						env_name: 'S3_PUBLISH_DRY_RUN',
						description: 'Toggle dry run',
						is_string: false,
						default_value: false
					)
				]
			end

			def self.output
				[
					['S3_PUBLISH_PUBLIC_FILE_URL', 'The public url of the :file that was uploaded.'],
					['S3_PUBLISH_PUBLIC_FOLDER_URL', 'The public url of the :folder that was uploaded.'],
					['S3_PUBLISH_PUBLIC_WEB_URL', 'The public url of the bucket the :web_folder was synced to.']
				]
			end

			def self.return_value
				nil
			end

			def self.authors
				["WTA"]
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
)',
'# Sync web folder
s3_publish(
	access_key: "aws access key",
	access_secret: "aws access secret",
	region: "us-east-1",
	bucket: "de-builds-staging",
	web_folder: "web/build"
)',
'# Sync web folder with `private` ACL permissions.
s3_publish(
	access_key: "aws access key",
	access_secret: "aws access secret",
	region: "us-east-1",
	bucket: "de-builds-staging",
	acl: "private",
	web_folder: "web/build"
)'
				]
			end

			def self.is_supported?(platform)
				true
			end
		end
	end
end
