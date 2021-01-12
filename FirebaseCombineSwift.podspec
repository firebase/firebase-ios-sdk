Pod::Spec.new do |s|
  s.name             = 'FirebaseCombineSwift'
  s.version          = '7.3.0'
  s.summary          = 'Swift extensions with Combine support for Firebase'

  s.description      = <<-DESC
Combine Publishers for Firebase.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'CocoaPods-' + s.version.to_s
  }

  s.social_media_url = 'https://twitter.com/Firebase'
  s.swift_version         = '5.0'
  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '13.0'
  s.tvos.deployment_target = '13.0'
  s.watchos.deployment_target = '7.0'

  s.cocoapods_version = '>= 1.4.0'
  s.prefix_header_file = false

  source = 'FirebaseCombineSwift/Sources/'
  s.exclude_files = [
    source + 'Core/**/*.swift',
  ]
  s.source_files = [
    source + '**/*.swift',
    source + '**/*.m',
  ]
  s.public_header_files = [
    source + '**/*.h',
  ]

  s.framework = 'Foundation'
  s.ios.framework = 'UIKit'
  s.osx.framework = 'AppKit'
  s.tvos.framework = 'UIKit'
  s.dependency 'FirebaseCore', '~> 7.0'
  s.dependency 'FirebaseAuth', '~> 7.0'

  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'GCC_PREPROCESSOR_DEFINITIONS' => 'Firebase_VERSION=' + s.version.to_s,
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}"',
    'OTHER_CFLAGS' => '-fno-autolink'
  }

  s.test_spec 'unit' do |unit_tests|
    unit_tests.platforms = {:ios => '13.0', :osx => '10.11', :tvos => '10.0'}
    unit_tests.source_files = [
      'FirebaseCombineSwift/Tests/Unit/**/*.swift',
      'FirebaseCombineSwift/Tests/Unit/**/*.h',
      'SharedTestUtilities/FIROptionsMock.[mh]',
    ]
    unit_tests.exclude_files = 'FirebaseCombineSwift/Tests/Unit/**/*Template.swift'
    unit_tests.pod_target_xcconfig = {
      'SWIFT_OBJC_BRIDGING_HEADER' => '$(PODS_TARGET_SRCROOT)/FirebaseCombineSwift/Tests/Unit/FirebaseCombineSwift-unit-Bridging-Header.h'
    }
    unit_tests.requires_app_host = true
    unit_tests.dependency 'OCMock'
  end
end
