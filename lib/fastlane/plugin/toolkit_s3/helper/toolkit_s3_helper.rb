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
				LOCAL = :local
				REMOTE = :remote
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

			Move = Struct.new(:file, :path)

			def self.s3_resource(params)
				access_key = params[Keys::ACCESS_KEY]
				access_secret = params[Keys::ACCESS_SECRET]
				region = params[Keys::REGION]
				Aws::S3::Resource.new(region: region, access_key_id: access_key, secret_access_key: access_secret)
			end

			def self.transfer(moves, params)
				s3 = s3_resource(params)
				s3_bucket = s3.bucket(params[Keys::BUCKET])
				s3_acl = params[Keys::ACL]
				move_number = 0
				total_moves = moves.count
				thread_count = params[Keys::THREADS]
				threads = []
				mutex = Mutex.new
				dry = params[Keys::DRY_RUN]

				thread_count.times do |i|
					threads[i] = Thread.new do
						until moves.empty?

							move = nil

							mutex.synchronize do
								move_number += 1
								move = moves.pop
								Thread.current['move_number'] = move_number
							end

							next unless move

							file = move.file
							path = move.path
							data = File.open(file)

							message("[#{Thread.current['move_number']}/#{total_moves}] is a directory") if File.directory?(data)

							unless File.directory?(data)
								obj = s3_bucket.object(path)
								content_type = mime_type(file)

								message("[#{Thread.current['move_number']}/#{total_moves}] uploading #{path} #{content_type}")
								obj.put({ acl: s3_acl.to_s, body: data, content_type: content_type }) unless dry
							end

							data.close
						end
					end
				end

				threads.each(&:join)

				# return the bucket since thats the most useful outside this method
				s3_bucket = s3.bucket(params[Keys::BUCKET])
			end
		end
	end
end
