Pod::Spec.new do |s|
  s.name             = 'FirebaseAuth'
  s.version          = '11.5.0'
  s.summary          = 'Apple platform client for Firebase Authentication'

  s.description      = <<-DESC
Firebase Authentication allows you to manage your own account system without any backend code. It
supports email and password accounts, as well as several 3rd party authentication mechanisms.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache-2.0', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'CocoaPods-' + s.version.to_s
  }

  s.social_media_url = 'https://twitter.com/Firebase'

  ios_deployment_target = '13.0'
  osx_deployment_target = '10.15'
  tvos_deployment_target = '13.0'
  watchos_deployment_target = '7.0'

  s.swift_version = '5.9'

  s.ios.deployment_target = ios_deployment_target
  s.osx.deployment_target = osx_deployment_target
  s.tvos.deployment_target = tvos_deployment_target
  s.watchos.deployment_target = watchos_deployment_target

  s.cocoapods_version = '>= 1.12.0'
  s.prefix_header_file = false

  source = 'FirebaseAuth/Sources/'
  s.source_files = [
    source + 'Swift/**/*.swift',
    source + 'ObjC/**/*.m', # Implementations for deprecated global symbols
    source + 'Public/FirebaseAuth/*.h'
  ]
  s.public_header_files = source + 'Public/FirebaseAuth/*.h'
  s.resource_bundles = {
    "#{s.module_name}_Privacy" => 'FirebaseAuth/Sources/Resources/PrivacyInfo.xcprivacy'
  }
  s.preserve_paths = [
    'FirebaseAuth/README.md',
    'FirebaseAuth/CHANGELOG.md'
  ]
  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    # The second path is to find FirebaseAuth-Swift.h from a pod gen project
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}" "${OBJECT_FILE_DIR_normal}/${NATIVE_ARCH_ACTUAL}"',
    'OTHER_SWIFT_FLAGS' => "$(inherited) #{ENV.key?('FIREBASE_CI') ? '-D FIREBASE_CI -warnings-as-errors' : ''}"
  }
  s.framework = 'Security'
  s.ios.framework = 'SafariServices'
  s.dependency 'FirebaseAuthInterop', '~> 11.0'
  s.dependency 'FirebaseAppCheckInterop', '~> 11.0'
  s.dependency 'FirebaseCore', '11.5'
  s.dependency 'FirebaseCoreExtension', '11.5'
  s.dependency 'GoogleUtilities/AppDelegateSwizzler', '~> 8.0'
  s.dependency 'GoogleUtilities/Environment', '~> 8.0'
  s.dependency 'GTMSessionFetcher/Core', '>= 3.4', '< 5.0'
  s.ios.dependency 'RecaptchaInterop', '~> 100.0'
  s.test_spec 'unit' do |unit_tests|
    unit_tests.scheme = { :code_coverage => true }
    # Unit tests can't run on watchOS.
    unit_tests.platforms = {
      :ios => ios_deployment_target,
      :osx => osx_deployment_target,
      :tvos => tvos_deployment_target
    }
    unit_tests.source_files = 'FirebaseAuth/Tests/Unit*/**/*.{m,h,swift}'
    # app_host is needed for tests with keychain
    unit_tests.requires_app_host = true
  end
end
