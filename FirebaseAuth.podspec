Pod::Spec.new do |s|
  s.name             = 'FirebaseAuth'
  s.version          = '10.9.0'
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
    source + 'Swift/**/*.swift',
    source + 'Public/FirebaseAuth/*.h'
  ]
  s.public_header_files = source + 'Public/FirebaseAuth/*.h'

  s.preserve_paths = [
    'FirebaseAuth/README.md',
    'FirebaseAuth/CHANGELOG.md'
  ]
  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    # The second path is to find FirebaseAuth-Swift.h from a pod gen project
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}" "${OBJECT_FILE_DIR_normal}/${NATIVE_ARCH_ACTUAL}"',
  }
  s.framework = 'Security'
  s.ios.framework = 'SafariServices'
  s.dependency 'FirebaseAuthInterop', '~> 10.9'
  s.dependency 'FirebaseAppCheckInterop', '~> 10.0'
  s.dependency 'FirebaseCore', '~> 10.0'
  s.dependency 'FirebaseCoreExtension', '~> 10.0'
  s.dependency 'GoogleUtilities/AppDelegateSwizzler', '~> 7.8'
  s.dependency 'GoogleUtilities/Environment', '~> 7.8'
  s.dependency 'GTMSessionFetcher/Core', '>= 2.1', '< 4.0'

  # Using environment variable because of the dependency on the unpublished
  # HeartbeatLoggingTestUtils.
  if ENV['POD_LIB_LINT_ONLY'] && ENV['POD_LIB_LINT_ONLY'] == '1' then
    s.test_spec 'unit' do |unit_tests|
      unit_tests.scheme = { :code_coverage => true }
      # Unit tests can't run on watchOS.
      unit_tests.platforms = {
        :ios => ios_deployment_target,
        :osx => osx_deployment_target,
        :tvos => tvos_deployment_target
      }
      unit_tests.source_files = 'FirebaseAuth/Tests/Unit*/**/*.{m,h,swift}'
      unit_tests.osx.exclude_files = [
        'FirebaseAuth/Tests/UnitObjC/FIRAuthAPNSTokenManagerTests.m',
        'FirebaseAuth/Tests/UnitObjC/FIRAuthAPNSTokenTests.m',
        'FirebaseAuth/Tests/UnitObjC/FIRAuthAppCredentialManagerTests.m',
        'FirebaseAuth/Tests/UnitObjC/FIRAuthNotificationManagerTests.m',
        'FirebaseAuth/Tests/UnitObjC/FIRAuthURLPresenterTests.m',
        'FirebaseAuth/Tests/UnitObjC/FIREmailLink*',
        'FirebaseAuth/Tests/UnitObjC/FIRPhoneAuthProviderTests.m',
        'FirebaseAuth/Tests/UnitObjC/FIRSendVerificationCode*',
        'FirebaseAuth/Tests/UnitObjC/FIRSignInWithGameCenterTests.m',
        'FirebaseAuth/Tests/UnitObjC/FIRVerifyClient*',
        'FirebaseAuth/Tests/UnitObjC/FIRVerifyPhoneNumber*',
        'FirebaseAuth/Tests/UnitObjC/FIROAuthProviderTests.m',
        'FirebaseAuth/Tests/UnitObjC/FIRMultiFactorResolverTests.m',
      ]
      unit_tests.tvos.exclude_files = [
        'FirebaseAuth/Tests/UnitObjC/FIRAuthAPNSTokenManagerTests.m',
        'FirebaseAuth/Tests/UnitObjC/FIRAuthNotificationManagerTests.m',
        'FirebaseAuth/Tests/UnitObjC/FIRAuthURLPresenterTests.m',
        'FirebaseAuth/Tests/UnitObjC/FIREmailLink*',
        'FirebaseAuth/Tests/UnitObjC/FIRPhoneAuthProviderTests.m',
        'FirebaseAuth/Tests/UnitObjC/FIRSendVerificationCode*',
        'FirebaseAuth/Tests/UnitObjC/FIRSignInWithGameCenterTests.m',
        'FirebaseAuth/Tests/UnitObjC/FIRVerifyClient*',
        'FirebaseAuth/Tests/UnitObjC/FIRVerifyPhoneNumber*',
        'FirebaseAuth/Tests/UnitObjC/FIROAuthProviderTests.m',
        'FirebaseAuth/Tests/UnitObjC/FIRMultiFactorResolverTests.m',
      ]
      # app_host is needed for tests with keychain
      unit_tests.requires_app_host = true
      unit_tests.dependency 'OCMock'
      unit_tests.dependency 'HeartbeatLoggingTestUtils'
    end
  end
end
