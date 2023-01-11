Pod::Spec.new do |s|
  s.name             = 'FirebaseAuth'
  s.version          = '10.12.0'
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

  ios_deployment_target = '11.0'
  osx_deployment_target = '10.13'
  tvos_deployment_target = '12.0'
  watchos_deployment_target = '6.0'

  s.swift_version = '5.3'

  s.ios.deployment_target = ios_deployment_target
  s.osx.deployment_target = osx_deployment_target
  s.tvos.deployment_target = tvos_deployment_target
  s.watchos.deployment_target = watchos_deployment_target

  s.cocoapods_version = '>= 1.4.0'
  s.prefix_header_file = false

  source = 'FirebaseAuth/Sources/'
  s.source_files = [
    'FirebaseAuth/Sources/Swift/**/*.swift',
    source + '**/*.[mh]',
    'FirebaseCore/Extension/*.h',
    'FirebaseAuth/Interop/*.h',
    'FirebaseAppCheck/Interop/*.h',
  ]
  s.public_header_files = source + 'Public/FirebaseAuth/*.h'
  s.preserve_paths = [
    'FirebaseAuth/README.md',
    'FirebaseAuth/CHANGELOG.md'
  ]
  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    # The second path is to find FirebaseAuth-Swift.h from a pod gen project
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}" "${OBJECT_FILE_DIR_normal}/${NATIVE_ARCH_ACTUAL}"'
  }
  s.framework = 'Security'
  s.ios.framework = 'SafariServices'
  s.dependency 'FirebaseAppCheckInterop', '~> 10.0'
  s.dependency 'FirebaseCore', '~> 10.0'
  s.dependency 'GoogleUtilities/AppDelegateSwizzler', '~> 7.8'
  s.dependency 'GoogleUtilities/Environment', '~> 7.8'
  s.dependency 'GTMSessionFetcher/Core', '>= 2.1', '< 4.0'

  s.test_spec 'unit' do |unit_tests|
    unit_tests.scheme = { :code_coverage => true }
    # Unit tests can't run on watchOS.
    unit_tests.platforms = {
      :ios => ios_deployment_target,
      :osx => osx_deployment_target,
      :tvos => tvos_deployment_target
    }
    unit_tests.source_files = 'FirebaseAuth/Tests/Unit/*.[mh]'
    unit_tests.osx.exclude_files = [
      'FirebaseAuth/Tests/Unit/FIRAuthAPNSTokenManagerTests.m',
      'FirebaseAuth/Tests/Unit/FIRAuthAPNSTokenTests.m',
      'FirebaseAuth/Tests/Unit/FIRAuthAppCredentialManagerTests.m',
      'FirebaseAuth/Tests/Unit/FIRAuthNotificationManagerTests.m',
      'FirebaseAuth/Tests/Unit/FIRAuthURLPresenterTests.m',
      'FirebaseAuth/Tests/Unit/FIREmailLink*',
      'FirebaseAuth/Tests/Unit/FIRPhoneAuthProviderTests.m',
      'FirebaseAuth/Tests/Unit/FIRSendVerificationCode*',
      'FirebaseAuth/Tests/Unit/FIRSignInWithGameCenterTests.m',
      'FirebaseAuth/Tests/Unit/FIRVerifyClient*',
      'FirebaseAuth/Tests/Unit/FIRVerifyPhoneNumber*',
      'FirebaseAuth/Tests/Unit/FIROAuthProviderTests.m',
      'FirebaseAuth/Tests/Unit/FIRMultiFactorResolverTests.m',
    ]
    unit_tests.tvos.exclude_files = [
      'FirebaseAuth/Tests/Unit/FIRAuthAPNSTokenManagerTests.m',
      'FirebaseAuth/Tests/Unit/FIRAuthNotificationManagerTests.m',
      'FirebaseAuth/Tests/Unit/FIRAuthURLPresenterTests.m',
      'FirebaseAuth/Tests/Unit/FIREmailLink*',
      'FirebaseAuth/Tests/Unit/FIRPhoneAuthProviderTests.m',
      'FirebaseAuth/Tests/Unit/FIRSendVerificationCode*',
      'FirebaseAuth/Tests/Unit/FIRSignInWithGameCenterTests.m',
      'FirebaseAuth/Tests/Unit/FIRVerifyClient*',
      'FirebaseAuth/Tests/Unit/FIRVerifyPhoneNumber*',
      'FirebaseAuth/Tests/Unit/FIROAuthProviderTests.m',
      'FirebaseAuth/Tests/Unit/FIRMultiFactorResolverTests.m',
    ]
    # app_host is needed for tests with keychain
    unit_tests.requires_app_host = true
    unit_tests.dependency 'OCMock'

    # This pre-processor directive is used to selectively disable keychain
    # related code that blocks unit testing on macOS.
    s.osx.pod_target_xcconfig = {
      'GCC_PREPROCESSOR_DEFINITIONS' => 'FIREBASE_AUTH_MACOS_TESTING=1'
    }

  end
end
