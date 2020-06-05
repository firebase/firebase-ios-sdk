Pod::Spec.new do |s|
  s.name             = 'FirebaseStorage'
  s.version          = '3.6.1-test'
  s.summary          = 'Firebase Storage'

  s.description      = <<-DESC
Firebase Storage provides robust, secure file uploads and downloads from Firebase SDKs, powered by Google Cloud Storage.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'Storage-' + s.version.to_s
  }
  s.social_media_url = 'https://twitter.com/Firebase'
  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.11'
  s.tvos.deployment_target = '10.0'
  # spec won't validate or push with FirebaseAuth as a test spec dependency.
#  s.watchos.deployment_target = '6.0'

  s.cocoapods_version = '>= 1.4.0'
  s.static_framework = true
  s.prefix_header_file = false

  s.source_files = 'FirebaseStorage/Sources/**/*.[mh]'
  s.public_header_files = 'FirebaseStorage/Sources/Public/*.h'
  s.preserve_paths = 'Interop/Auth/Public/*.h', 'FirebaseCore/Sources/Private/*.h'

  s.ios.framework = 'MobileCoreServices'
  s.osx.framework = 'CoreServices'

  s.dependency 'FirebaseAuthInterop', '~> 1.1'
  s.dependency 'FirebaseCore', '~> 6.6'
  s.dependency 'GTMSessionFetcher/Core', '~> 1.1'
  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'GCC_PREPROCESSOR_DEFINITIONS' =>
      'FIRStorage_VERSION=' + s.version.to_s,
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}"'
  }

  s.test_spec 'unit' do |unit_tests|
    unit_tests.source_files = 'FirebaseStorage/Tests/Unit/*.[mh]',
                              'Example/Shared/FIRComponentTestUtilities.*',
                              'Example/Shared/FIRAuthInteropFake.*'
    unit_tests.dependency 'OCMock'
  end

  s.test_spec 'integration' do |int_tests|
    int_tests.source_files = 'FirebaseStorage/Tests/Integration/*.[mh]'
    int_tests.requires_app_host = true
    int_tests.resources = 'FirebaseStorage/Tests/Integration/Resources/1mb.dat',
                          'FirebaseStorage/Tests/Integration/Resources/GoogleService-Info.plist'
    int_tests.dependency 'FirebaseAuth', '~> 6.5'
  end

  s.test_spec 'swift-integration' do |swift_int_tests|
    swift_int_tests.platforms = {:ios => '8.0', :osx => '10.11', :tvos => '10.0'}
    swift_int_tests.source_files = 'FirebaseStorage/Tests/SwiftIntegration/*.swift'
    swift_int_tests.requires_app_host = true
    swift_int_tests.resources = 'FirebaseStorage/Tests/Integration/Resources/1mb.dat',
                          'FirebaseStorage/Tests/Integration/Resources/GoogleService-Info.plist'
    swift_int_tests.dependency 'FirebaseAuth', '~> 6.5'
  end
end
