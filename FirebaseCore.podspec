Pod::Spec.new do |s|
  s.name             = 'FirebaseCore'
  s.version          = '11.5.0'
  s.summary          = 'Firebase Core'

  s.description      = <<-DESC
Firebase Core includes FIRApp and FIROptions which provide central configuration for other Firebase services.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache-2.0', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'CocoaPods-' + s.version.to_s
  }

  s.social_media_url = 'https://twitter.com/Firebase'

  ios_deployment_target = '12.0'
  osx_deployment_target = '10.15'
  tvos_deployment_target = '13.0'
  watchos_deployment_target = '7.0'

  s.ios.deployment_target = ios_deployment_target
  s.osx.deployment_target = osx_deployment_target
  s.tvos.deployment_target = tvos_deployment_target
  s.watchos.deployment_target = watchos_deployment_target

  s.cocoapods_version = '>= 1.12.0'
  s.prefix_header_file = false

  s.source_files = [
    'FirebaseCore/Sources/**/*.[mh]',
    'FirebaseCore/Extension/*.h'
  ]

  s.resource_bundles = {
    "#{s.module_name}_Privacy" => 'FirebaseCore/Sources/Resources/PrivacyInfo.xcprivacy'
  }

  s.swift_version = '5.9'

  s.public_header_files = 'FirebaseCore/Sources/Public/FirebaseCore/*.h'

  s.framework = 'Foundation'
  s.ios.framework = 'UIKit'
  s.osx.framework = 'AppKit'
  s.tvos.framework = 'UIKit'
  s.watchos.framework = 'WatchKit'

  # Remember to also update version in `cmake/external/GoogleUtilities.cmake`
  s.dependency 'GoogleUtilities/Environment', '~> 8.0'
  s.dependency 'GoogleUtilities/Logger', '~> 8.0'
  s.dependency 'FirebaseCoreInternal', '11.5'

  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'GCC_PREPROCESSOR_DEFINITIONS' => 'Firebase_VERSION=' + s.version.to_s,
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}"',
    'OTHER_CFLAGS' => '-fno-autolink'
  }

  s.test_spec 'unit' do |unit_tests|
    unit_tests.scheme = { :code_coverage => true }
    unit_tests.platforms = {
      :ios => ios_deployment_target,
      :osx => '10.15',
      :tvos => tvos_deployment_target
    }
    unit_tests.source_files = [
      'FirebaseCore/Tests/Unit/**/*.[mh]',
      'SharedTestUtilities/FIROptionsMock.[mh]',
    ]

    unit_tests.requires_app_host = true
    unit_tests.dependency 'OCMock'
    unit_tests.resources = 'FirebaseCore/Tests/Unit/Resources/GoogleService-Info.plist'
  end

  s.test_spec 'swift-unit' do |swift_unit_tests|
    swift_unit_tests.platforms = {
      :ios => ios_deployment_target,
      :osx => osx_deployment_target,
      :tvos => tvos_deployment_target
    }
    swift_unit_tests.source_files = [
      'FirebaseCore/Tests/SwiftUnit/**/*.swift',
      'FirebaseCore/Tests/SwiftUnit/**/*.h',
      'FirebaseCore/Tests/SwiftUnit/SwiftTestingUtilities/*',
      'SharedTestUtilities/ExceptionCatcher.[mh]',
      'SharedTestUtilities/FIROptionsMock.[mh]',
    ]
    swift_unit_tests.pod_target_xcconfig = {
      'SWIFT_OBJC_BRIDGING_HEADER' => '$(PODS_TARGET_SRCROOT)/FirebaseCore/Tests/SwiftUnit/FirebaseCore-unit-Bridging-Header.h'
    }
    swift_unit_tests.requires_app_host = true
    swift_unit_tests.dependency 'OCMock'
    swift_unit_tests.resources = 'FirebaseCore/Tests/Unit/Resources/GoogleService-Info.plist'
  end
end
