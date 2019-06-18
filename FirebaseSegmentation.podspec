Pod::Spec.new do |s|
  s.name             = 'FirebaseSegmentation'
  s.version          = '0.1.0'
  s.summary          = 'Firebase Segmentation SDK'
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

  s.source_files = 'Segmentation/Sources/**/*'
  s.public_header_files = 'Segmentation/Sources/Public/*.h'

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
