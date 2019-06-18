#
# Be sure to run `pod lib lint FirebaseSegmentation.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'FirebaseSegmentation'
  s.version          = '0.1.0'
  s.summary          = 'Firebase Segmentation SDK for user segmentation.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
Firebase Segmentation enables you to associate your custom application instance ID with Firebase for user segmentation.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'
  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'Segmentation-' + s.version.to_s
  }

  s.ios.deployment_target = '8.0'
  
  s.cocoapods_version = '>= 1.4.0'
  s.static_framework = true
  s.prefix_header_file = false

  s.source_files = 'Segmentation/**/*'
  s.public_header_files = 'Segmentation/Public/*.h'

  s.dependency 'FirebaseCore', '~> 6.0'
  s.dependency 'FirebaseInstanceID', '~> 4.1.1'

s.user_target_xcconfig = { 'FRAMEWORK_SEARCH_PATHS' => '$(PLATFORM_DIR)/Developer/Library/Frameworks' }

  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'GCC_PREPROCESSOR_DEFINITIONS' => 'FIRSegmentation_VERSION=' + s.version.to_s
  }

  s.test_spec 'unit' do |unit_tests|
    unit_tests.source_files = 'Segmentation/Tests/Unit/*.[mh]'
    unit_tests.dependency 'OCMock'
  end

end
