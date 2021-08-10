Pod::Spec.new do |s|
  s.name             = 'FirebaseFunctions'
  s.version          = '8.6.0'
  s.summary          = 'Cloud Functions for Firebase'

  s.description      = <<-DESC
Cloud Functions for Firebase.
                       DESC

  s.homepage         = 'https://developers.google.com/'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'
  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'CocoaPods-' + s.version.to_s
  }

  s.ios.deployment_target = '10.0'
  s.osx.deployment_target = '10.12'
  s.tvos.deployment_target = '10.0'

  s.cocoapods_version = '>= 1.4.0'
  s.prefix_header_file = false

  s.source_files = [
    'Functions/FirebaseFunctions/**/*',
    'Interop/Auth/Public/*.h',
    'FirebaseAppCheck/Sources/Interop/*.h',
    'FirebaseCore/Sources/Private/*.h',
    'FirebaseMessaging/Sources/Interop/FIRMessagingInterop.h',
  ]
  s.public_header_files = 'Functions/FirebaseFunctions/Public/FirebaseFunctions/*.h'

  s.dependency 'FirebaseCore', '~> 8.0'
  s.dependency 'GTMSessionFetcher/Core', '~> 1.5'

  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}"'
  }

  s.test_spec 'unit' do |unit_tests|
    unit_tests.scheme = { :code_coverage => true }
    unit_tests.source_files = [
      'Functions/Example/Test*/*.[mh]',
      'Functions/Tests/Unit/Swift/**/*',
      'SharedTestUtilities/FIRAuthInteropFake*',
      'SharedTestUtilities/FIRMessagingInteropFake*',
      'SharedTestUtilities/AppCheckFake/*.[mh]',
  ]
  end

  s.test_spec 'integration' do |int_tests|
    int_tests.scheme = { :code_coverage => true }
    int_tests.source_files = 'Functions/Example/IntegrationTests/*.[mh]',
                             'Functions/Example/TestUtils/*.[mh]',
                             'SharedTestUtilities/FIRAuthInteropFake*',
                             'SharedTestUtilities/FIRMessagingInteropFake*',
                             'Functions/Example/GoogleService-Info.plist'
  end
end
