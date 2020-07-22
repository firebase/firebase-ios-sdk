Pod::Spec.new do |s|
  s.name             = 'FirebaseAuth'
  s.version          = '6.7.1'
  s.summary          = 'Apple platform client for Firebase Authentication'

  s.description      = <<-DESC
Firebase Authentication allows you to manage your own account system without any backend code. It
supports email and password accounts, as well as several 3rd party authentication mechanisms.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'Auth-' + s.version.to_s
  }
  s.social_media_url = 'https://twitter.com/Firebase'
  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.11'
  s.tvos.deployment_target = '10.0'

  s.cocoapods_version = '>= 1.4.0'
  s.static_framework = true
  s.prefix_header_file = false

  source = 'FirebaseAuth/Sources/'
  s.source_files = [
    source + '**/*.[mh]',
    'FirebaseCore/Sources/Private/*.h',
    'GoogleUtilities/AppDelegateSwizzler/Private/*.h',
    'GoogleUtilities/Environment/Private/*.h',
    'GoogleUtilities/SceneDelegateSwizzler/Private/*.h',
    'Interop/Auth/Public/*.h',
  ]
  s.public_header_files = source + 'Public/*.h'
  s.preserve_paths = [
    'FirebaseAuth/README.md',
    'FirebaseAuth/CHANGELOG.md'
  ]
  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'GCC_PREPROCESSOR_DEFINITIONS' =>
      'FIRAuth_VERSION=' + s.version.to_s +
      ' FIRAuth_MINOR_VERSION=' + s.version.to_s.split(".")[0] + "." + s.version.to_s.split(".")[1],
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}"'
  }
  s.framework = 'Security'
  s.ios.framework = 'SafariServices'
  s.dependency 'FirebaseCore', '~> 6.8'
  s.dependency 'GoogleUtilities/AppDelegateSwizzler', '~> 6.7'
  s.dependency 'GoogleUtilities/Environment', '~> 6.7'
  s.dependency 'GTMSessionFetcher/Core', '~> 1.1'

  s.test_spec 'unit' do |unit_tests|
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
    ]
    # app_host is needed for tests with keychain
    unit_tests.requires_app_host = true
    unit_tests.dependency 'OCMock'
  end
end
