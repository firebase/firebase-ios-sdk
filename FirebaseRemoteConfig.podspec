Pod::Spec.new do |s|
  s.name             = 'FirebaseRemoteConfig'
  s.version          = '4.4.11'
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
  s.source_files = base_dir + '**/*.[mh]'
  s.public_header_files = base_dir + 'Public/*.h'
  s.private_header_files = base_dir + 'Private/*.h'
  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'GCC_PREPROCESSOR_DEFINITIONS' =>
      'GPB_USE_PROTOBUF_FRAMEWORK_IMPORTS=1 ' +
      'FIRRemoteConfig_VERSION=' + String(s.version),
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}"'
  }
  s.dependency 'FirebaseAnalyticsInterop', '~> 1.4'
  s.dependency 'FirebaseABTesting', '~> 3.1'
  s.dependency 'FirebaseCore', '~> 6.2'
  s.dependency 'FirebaseInstallations', '~> 1.1'
  s.dependency 'GoogleUtilities/Environment', '~> 6.2'
  s.dependency 'GoogleUtilities/NSData+zlib', '~> 6.2'

  s.test_spec 'unit' do |unit_tests|
    # TODO(dmandar) - Update or delete the commented files.
    unit_tests.source_files =
        'FirebaseRemoteConfig/Tests/Unit/FIRRemoteConfigComponentTest.m',
        'FirebaseRemoteConfig/Tests/Unit/RCNConfigContentTest.m',
        'FirebaseRemoteConfig/Tests/Unit/RCNConfigDBManagerTest.m',
#        'FirebaseRemoteConfig/Tests/Unit/RCNConfigSettingsTest.m',
#        'FirebaseRemoteConfig/Tests/Unit/RCNConfigTest.m',
        'FirebaseRemoteConfig/Tests/Unit/RCNConfigExperimentTest.m',
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
        'FirebaseRemoteConfig/Tests/Unit/SecondApp-GoogleService-Info.plist'
    unit_tests.requires_app_host = true
    unit_tests.dependency 'OCMock'
    unit_tests.requires_arc = true
  end

  s.test_spec 'swift-api' do |swift_api_tests|
    swift_api_tests.platforms = {:ios => '8.0', :osx => '10.11', :tvos => '10.0'}
    swift_api_tests.source_files = 'FirebaseRemoteConfig/Tests/SwiftAPI/*.swift'
    swift_api_tests.requires_app_host = true
    swift_api_tests.resources =
        'FirebaseRemoteConfig/Tests/SwiftAPI/GoogleService-Info.plist'
  end

  s.test_spec 'hermetic-api' do |hermetic_api_tests|
    hermetic_api_tests.platforms = {:ios => '8.0', :osx => '10.11', :tvos => '10.0'}
    hermetic_api_tests.source_files = 'FirebaseRemoteConfig/Tests/HermeticAPI/*.swift',
                                      'FirebaseRemoteConfig/Tests/HermeticAPI/*.h'
    hermetic_api_tests.requires_app_host = true
    hermetic_api_tests.pod_target_xcconfig = {
      'SWIFT_OBJC_BRIDGING_HEADER' => '$(PODS_TARGET_SRCROOT)/FirebaseRemoteConfig/Tests/HermeticAPI/Bridging-Header.h'
    }
    hermetic_api_tests.resources =
        'FirebaseRemoteConfig/Tests/HermeticAPI/GoogleService-Info.plist'
  end
end
