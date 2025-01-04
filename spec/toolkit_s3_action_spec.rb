describe Fastlane::Actions::ToolkitS3Action do
	describe '#run' do
		it 'prints a message' do
			expect(Fastlane::UI).to receive(:message).with("The toolkit_s3 plugin is working!")

			Fastlane::Actions::ToolkitS3Action.run(nil)
		end
	end
end
