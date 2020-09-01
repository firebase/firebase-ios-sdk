Pod::Spec.new do |s|
  s.name             = 'FirebaseRemoteConfig'
  s.version          = '4.9.0'
  s.summary          = 'Firebase Remote Config'

  s.description      = <<-DESC
Firebase Remote Config is a cloud service that lets you change the
appearance and behavior of your app without requiring users to download an
app update.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'RemoteConfig-' + s.version.to_s
  }
  s.social_media_url = 'https://twitter.com/Firebase'
  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.11'
  s.tvos.deployment_target = '10.0'

  s.cocoapods_version = '>= 1.4.0'
  s.static_framework = true
  s.prefix_header_file = false

  base_dir = "FirebaseRemoteConfig/Sources/"
  s.source_files = [
    base_dir + '**/*.[mh]',
    'Interop/Analytics/Public/*.h',
    'FirebaseABTesting/Sources/Interop/*.h',
    'FirebaseCore/Sources/Private/*.h',
    'FirebaseInstallations/Source/Library/Private/*.h',
    'GoogleUtilities/Environment/Private/*.h',
    'GoogleUtilities/NSData+zlib/Private/*.h',
  ]
  s.public_header_files = base_dir + 'Public/FirebaseRemoteConfig/*.h'
  s.private_header_files = base_dir + 'Private/*.h'
  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'GCC_PREPROCESSOR_DEFINITIONS' =>
      'GPB_USE_PROTOBUF_FRAMEWORK_IMPORTS=1 ' +
      'FIRRemoteConfig_VERSION=' + String(s.version),
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}"'
  }
  # TODO(7.0) The FirebaseABTesting dependency should be removed at next major version update.
  s.dependency 'FirebaseABTesting', '~> 4.2'
  s.dependency 'FirebaseCore', '~> 6.10'
  s.dependency 'FirebaseInstallations', '~> 1.6'
  s.dependency 'GoogleUtilities/Environment', '~> 6.7'
  s.dependency 'GoogleUtilities/NSData+zlib', '~> 6.7'

  s.test_spec 'unit' do |unit_tests|
    # TODO(dmandar) - Update or delete the commented files.
    unit_tests.source_files =
        'FirebaseRemoteConfig/Tests/Unit/FIRRemoteConfigComponentTest.m',
        'FirebaseRemoteConfig/Tests/Unit/RCNConfigContentTest.m',
        'FirebaseRemoteConfig/Tests/Unit/RCNConfigDBManagerTest.m',
#        'FirebaseRemoteConfig/Tests/Unit/RCNConfigSettingsTest.m',
#        'FirebaseRemoteConfig/Tests/Unit/RCNConfigTest.m',
        'FirebaseRemoteConfig/Tests/Unit/RCNConfigValueTest.m',
#        'FirebaseRemoteConfig/Tests/Unit/RCNRemoteConfig+FIRAppTest.m',
        'FirebaseRemoteConfig/Tests/Unit/RCNRemoteConfigTest.m',
#        'FirebaseRemoteConfig/Tests/Unit/RCNThrottlingTests.m',
        'FirebaseRemoteConfig/Tests/Unit/RCNTestUtilities.m',
        'FirebaseRemoteConfig/Tests/Unit/RCNUserDefaultsManagerTests.m',
        'FirebaseRemoteConfig/Tests/Unit/RCNTestUtilities.h',
        'FirebaseRemoteConfig/Tests/Unit/RCNInstanceIDTest.m'
    # Supply plist custom plist testing.
    unit_tests.resources =
        'FirebaseRemoteConfig/Tests/Unit/Defaults-testInfo.plist',
        'FirebaseRemoteConfig/Tests/Unit/SecondApp-GoogleService-Info.plist',
        'FirebaseRemoteConfig/Tests/Unit/TestABTPayload.txt'
    unit_tests.requires_app_host = true
    unit_tests.dependency 'OCMock'
    unit_tests.requires_arc = true
  end

  # Separate unit tests that require FirebaseABTesting.
  s.test_spec 'abt' do |abt|
    abt.source_files = [
        'FirebaseRemoteConfig/Tests/Unit/RCNConfigExperimentTest.m',
        'FirebaseRemoteConfig/Tests/Unit/RCNTestUtilities.[hm]',
        'FirebaseABTesting/Sources/Private/*.h',
    ]
    abt.resources = [
        'FirebaseRemoteConfig/Tests/Unit/TestABTPayload.txt',
    ]
    abt.requires_app_host = true
    abt.dependency 'OCMock'
    abt.dependency 'FirebaseABTesting', '~> 4.2'
    abt.requires_arc = true
  end

  # Run Swift API tests on a real backend.
  s.test_spec 'swift-api-tests' do |swift_api|
    swift_api.platforms = {:ios => '8.0', :osx => '10.11', :tvos => '10.0'}
    swift_api.source_files = 'FirebaseRemoteConfig/Tests/SwiftAPI/*.swift',
                             'FirebaseRemoteConfig/Tests/FakeUtils/*.[hm]',
                             'FirebaseRemoteConfig/Tests/FakeUtils/*.swift'
    swift_api.requires_app_host = true
    swift_api.pod_target_xcconfig = {
      'SWIFT_OBJC_BRIDGING_HEADER' => '$(PODS_TARGET_SRCROOT)/FirebaseRemoteConfig/Tests/FakeUtils/Bridging-Header.h'
    }
    swift_api.resources = 'FirebaseRemoteConfig/Tests/SwiftAPI/GoogleService-Info.plist',
                          'FirebaseRemoteConfig/Tests/SwiftAPI/AccessToken.json'
    swift_api.dependency 'OCMock'
  end

  # Run Swift API tests and tests requiring console changes on a Fake Console.
  s.test_spec 'fake-console-tests' do |fake_console|
    fake_console.platforms = {:ios => '8.0', :osx => '10.11', :tvos => '10.0'}
    fake_console.source_files = 'FirebaseRemoteConfig/Tests/SwiftAPI/*.swift',
                                      'FirebaseRemoteConfig/Tests/FakeUtils/*.[hm]',
                                      'FirebaseRemoteConfig/Tests/FakeUtils/*.swift',
                                      'FirebaseRemoteConfig/Tests/FakeConsole/*.swift'
    fake_console.requires_app_host = true
    fake_console.pod_target_xcconfig = {
      'SWIFT_OBJC_BRIDGING_HEADER' => '$(PODS_TARGET_SRCROOT)/FirebaseRemoteConfig/Tests/FakeUtils/Bridging-Header.h'
    }
    fake_console.resources = 'FirebaseRemoteConfig/Tests/FakeUtils/GoogleService-Info.plist'
    fake_console.dependency 'OCMock'
  end
end
