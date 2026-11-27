Pod::Spec.new do |s|
  s.name             = 'FirebaseAppCheck'
  s.version          = '13.3.0'
  s.summary          = 'Firebase App Check SDK.'

  s.description      = <<-DESC
  Firebase SDK for anti-abuse compatibility.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache-2.0', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'CocoaPods-' + s.version.to_s
  }
  s.social_media_url = 'https://twitter.com/Firebase'

  ios_deployment_target = '15.0'
  osx_deployment_target = '11.0'
  tvos_deployment_target = '15.0'
  watchos_deployment_target = '8.0'

  s.swift_version = '5.9'

  s.ios.deployment_target = ios_deployment_target
  s.osx.deployment_target = osx_deployment_target
  s.tvos.deployment_target = tvos_deployment_target
  s.watchos.deployment_target = watchos_deployment_target

  s.cocoapods_version = '>= 1.12.0'
  s.prefix_header_file = false

  base_dir = "FirebaseAppCheck/"

  # The public API is declared in Objective-C headers and implemented in Swift with
  # `@objc @implementation` extensions. `FIRAppCheckInternal.h` declares the internal
  # `FIRAppCheckInterop` conformance that `FIRAppCheck` implements; it is not imported by
  # `FirebaseAppCheck.h`. SwiftPM and binary distributions keep it in the explicit submodule
  # `FirebaseAppCheck.Internal`; CocoaPods (internal testing only) includes it in
  # `public_header_files` so both framework and `--use-modular-headers` static-library builds see
  # the conformance through the generated umbrella header.
  s.source_files = [
    base_dir + 'Sources/Swift/**/*.swift',
    base_dir + 'Sources/ObjC/**/*.[mh]',
    base_dir + 'Sources/Public/FirebaseAppCheck/*.h',
    base_dir + 'Sources/Private/*.h',
  ]
  s.public_header_files = [
    base_dir + 'Sources/Public/FirebaseAppCheck/*.h',
    base_dir + 'Sources/Private/*.h',
  ]

  s.ios.weak_framework = 'DeviceCheck'
  s.osx.weak_framework = 'DeviceCheck'
  s.tvos.weak_framework = 'DeviceCheck'

  s.dependency 'AppCheckCore', '~> 12.1'
  s.dependency 'FirebaseAppCheckInterop', '~> 13.3.0'
  s.dependency 'FirebaseCore', '~> 13.3.0'
  s.dependency 'FirebaseCoreExtension', '~> 13.3.0'
  s.dependency 'GoogleUtilities/UserDefaults', '>= 8.1.3', '< 9.0'

  s.pod_target_xcconfig = {
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}"',
    'OTHER_SWIFT_FLAGS' => "$(inherited) #{ENV.key?('FIREBASE_CI') ? '-D FIREBASE_CI -warnings-as-errors' : ''}",
    'PRODUCT_BUNDLE_IDENTIFIER' => 'com.google.firebase.FirebaseAppCheck'
  }

  s.test_spec 'unit' do |unit_tests|
    unit_tests.platforms = {
      :ios => ios_deployment_target,
      :osx => osx_deployment_target,
      :tvos => tvos_deployment_target
    }
    unit_tests.source_files = [
      base_dir + 'Tests/Unit/ObjCAPI/*.[mh]',
      base_dir + 'Tests/Unit/DebugProvider/*.[mh]',
      base_dir + 'Tests/Unit/DeviceCheckProvider/*.[mh]',
    ]
    unit_tests.requires_app_host = true
  end

  s.test_spec 'integration' do |integration_tests|
    integration_tests.platforms = {
      :ios => ios_deployment_target,
      :osx => osx_deployment_target,
      :tvos => tvos_deployment_target
    }
    integration_tests.source_files = [
      base_dir + 'Tests/Integration/**/*.swift',
    ]
    integration_tests.requires_app_host = true
  end

  s.test_spec 'swift-unit' do |swift_unit_tests|
    swift_unit_tests.platforms = {
      :ios => ios_deployment_target,
      :osx => osx_deployment_target,
      :tvos => tvos_deployment_target
    }
    swift_unit_tests.source_files = [
      base_dir + 'Tests/Unit/Swift/**/*.swift',
      'SharedTestUtilities/ExceptionCatcher.[mh]'
    ]
    swift_unit_tests.pod_target_xcconfig = {
      'SWIFT_OBJC_BRIDGING_HEADER' => '$(PODS_TARGET_SRCROOT)/FirebaseAppCheck/Tests/Unit/Swift/FirebaseAppCheck-unit-Bridging-Header.h'
    }

    swift_unit_tests.dependency 'AppCheckCore', '~> 12.1'
    swift_unit_tests.dependency 'FirebaseCoreExtension', '~> 13.3.0'
  end

end
