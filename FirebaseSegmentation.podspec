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

  s.source_files = 'FirebaseSegmentation/Sources/**/*.[mh]'
  s.public_header_files = 'FirebaseSegmentation/Sources/Public/*.h'

  s.dependency 'FirebaseCore', '~> 6.1'
  s.dependency 'FirebaseInstanceID', '~> 4.2'

   header_search_paths = {
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}"'
  }

  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'GCC_PREPROCESSOR_DEFINITIONS' => 'FIRSegmentation_VERSION=' + s.version.to_s
  }.merge(header_search_paths)

  s.test_spec 'unit' do |unit_tests|
    unit_tests.source_files = 'FirebaseSegmentation/Tests/Unit/*.[mh]'
    unit_tests.dependency 'OCMock'
    unit_tests.requires_app_host = true
  end
end
