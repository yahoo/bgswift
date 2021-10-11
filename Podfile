use_frameworks!

platform :ios, '12.0'
project 'Example/BGSwift.xcodeproj'

target 'BGSwift-Example' do
  pod 'BGSwift', :path => '.'

  target 'BGSwift-Tests' do
    inherit! :search_paths

    pod 'Quick', '~> 4.0'
    pod 'Nimble', '~> 9.2'
  end
end

#post_install do |installer|
#  installer.generated_projects.each do |project|
#      project.build_configurations.each do |configuration|
#          configuration.build_settings["ENABLE_TESTABILITY"] = "YES"
#      end
#  end
#end
