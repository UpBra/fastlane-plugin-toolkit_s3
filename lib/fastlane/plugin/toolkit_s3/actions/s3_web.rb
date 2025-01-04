# -------------------------------------------------------------------------
#
# S3 Web
# Deploys a folder to S3.
#
# -------------------------------------------------------------------------

require 'aws-sdk-s3'

module Fastlane

	module Actions

		module SharedValues
			S3_WEB_PUBLIC_URL = :S3_WEB_PUBLIC_URL
		end

		class S3WebAction < Action

			def self.run(params)
				aws_key = params[:access_key]
				aws_secret = params[:access_secret]
				region = params[:region]
				bucket = params[:bucket]
				folder_path = params[:folder]
				verbose = params[:verbose]
				thread_count = params[:threads]
				dry_run = params[:dry_run]

				UI.user_error! "#{self.name}: Missing AWS Access Key" if aws_key.nil? || aws_key.empty?
				UI.user_error! "#{self.name}: Missing AWS Access Secret" if aws_secret.nil?
				UI.user_error! "#{self.name}: Missing Region" if region.nil?
				UI.user_error! "#{self.name}: Missing Bucket" if bucket.nil?
				UI.user_error! "#{self.name}: Missing Folder" if folder_path.nil?

				FastlaneCore::PrintTable.print_values(
					config: params,
					title: "Summary for s3_web",
					mask_keys: [:access_key, :access_secret]
				)

				files = Dir.glob("#{folder_path}/**/*")
				total_files = files.length
				connection = Aws::S3::Resource.new(region: region, access_key_id: aws_key, secret_access_key: aws_secret)
				s3_bucket = connection.bucket(bucket)
				file_number = 0
				mutex = Mutex.new
				threads = []

				UI.message "Removing files on #{bucket}..." if verbose
				s3_bucket.objects.batch_delete! unless dry_run
				UI.message "#{bucket} cleared." if verbose

				UI.message "Total files: #{total_files}" if verbose
				UI.message "Thread Count: #{thread_count}" if verbose

				thread_count.times do |i|
					threads[i] = Thread.new {
						until files.empty?

						mutex.synchronize do
							file_number += 1
							Thread.current['file_number'] = file_number
						end

						file = files.pop rescue nil
							next unless file

							path = file.sub(/^#{folder_path}\//, '')
							data = File.open(file)

							unless File.directory?(data)
								obj = s3_bucket.object(path)
								content_type = mime_type(file)

								UI.message "[#{Thread.current["file_number"]}/#{total_files}] uploading #{path} #{content_type}" if verbose
								obj.put({ acl: "public-read", body: data, content_type: content_type }) unless dry_run
							end

							data.close
						end
					}
				end

				threads.each { |t| t.join }

				UI.message s3_bucket.url if verbose

				lane_context[SharedValues::S3_WEB_PUBLIC_URL] = s3_bucket.url
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

			def self.description
				'Deploys the contents of a folder as a website to S3'
			end

			def self.available_options
				[
					FastlaneCore::ConfigItem.new(
						key: :access_key,
						env_name: 'S3_WEB_ACCESS_KEY',
						description: 'AWS Access Key',
						is_string: true,
						optional: true
					),
					FastlaneCore::ConfigItem.new(
						key: :access_secret,
						env_name: 'S3_WEB_ACCESS_SECRET',
						description: 'AWS Access Secret',
						is_string: true,
						optional: true
					),
					FastlaneCore::ConfigItem.new(
						key: :region,
						env_name: 'S3_WEB_REGION',
						description: 'Name of the S3 bucket',
						is_string: true,
						optional: true
					),
					FastlaneCore::ConfigItem.new(
						key: :bucket,
						env_name: 'S3_WEB_BUCKET',
						description: 'Name of the S3 bucket',
						is_string: true,
						optional: true
					),
					FastlaneCore::ConfigItem.new(
						key: :folder,
						env_name: 'S3_WEB_FOLDER',
						description: 'The folder to upload',
						is_string: true,
						optional: true
					),
					FastlaneCore::ConfigItem.new(
						key: :threads,
						env_name: 'S3_WEB_THREADS',
						description: 'Count of threads',
						is_string: false,
						default_value: 3
					),
					FastlaneCore::ConfigItem.new(
						key: :verbose,
						env_name: 'S3_WEB_VERBOSE',
						description: 'Toggle verbose output',
						is_string: false,
						default_value: false
					),
					FastlaneCore::ConfigItem.new(
						key: :dry_run,
						env_name: 'S3_WEB_DRY_RUN',
						description: 'Toggle dry run',
						is_string: false,
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
