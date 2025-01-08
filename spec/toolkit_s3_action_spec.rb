
describe Fastlane::Helper::ToolkitS3Helper do

	describe '#message' do

		it 'prints a message' do
			expect(Fastlane::UI).to receive(:message).with("The plugin is working!")
			Fastlane::Helper::ToolkitS3Helper.message("The plugin is working!")
		end
	end
end
