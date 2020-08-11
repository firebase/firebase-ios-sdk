Pod::Spec.new do |s|
  s.name             = 'FirebaseFunctions'
  s.version          = '2.8.0'
  s.summary          = 'Cloud Functions for Firebase'

  s.description      = <<-DESC
Cloud Functions for Firebase.
                       DESC

  s.homepage         = 'https://developers.google.com/'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'
  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'Functions-' + s.version.to_s
  }

  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.11'
  s.tvos.deployment_target = '10.0'

  s.cocoapods_version = '>= 1.4.0'
  s.static_framework = true
  s.prefix_header_file = false

  s.source_files = [
    'Functions/FirebaseFunctions/**/*',
    'Interop/Auth/Public/*.h',
    'FirebaseCore/Sources/Private/*.h',
  ]
  s.public_header_files = 'Functions/FirebaseFunctions/Public/FirebaseFunctions/*.h'

  s.dependency 'FirebaseCore', '~> 6.10'
  s.dependency 'GTMSessionFetcher/Core', '~> 1.1'

  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'GCC_PREPROCESSOR_DEFINITIONS' => 'FIRFunctions_VERSION=' + s.version.to_s,
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}"'
  }

  s.test_spec 'unit' do |unit_tests|
    unit_tests.source_files = 'Functions/Example/Test*/*.[mh]', 'SharedTestUtilities/FIRAuthInteropFake*'
  end

  s.test_spec 'integration' do |int_tests|
    int_tests.source_files = 'Functions/Example/IntegrationTests/*.[mh]',
                             'Functions/Example/TestUtils/*.[mh]',
                             'SharedTestUtilities/FIRAuthInteropFake*',
                             'Functions/Example/GoogleService-Info.plist'
  end
end
