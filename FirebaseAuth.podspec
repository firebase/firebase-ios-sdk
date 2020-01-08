Pod::Spec.new do |s|
  s.name             = 'FirebaseAuth'
  s.version          = '6.4.1'
  s.summary          = 'The official iOS client for Firebase Authentication (plus community support for macOS and tvOS)'

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
  s.watchos.deployment_target = '6.0'

  s.cocoapods_version = '>= 1.4.0'
  s.static_framework = true
  s.prefix_header_file = false

  source = 'Firebase/Auth/Source/'
  s.source_files = source + '**/*.[mh]'
  s.public_header_files = source + 'Public/*.h'
  s.preserve_paths = [
    'Firebase/Auth/README.md',
    'Firebase/Auth/CHANGELOG.md'
  ]
  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'GCC_PREPROCESSOR_DEFINITIONS' =>
      'FIRAuth_VERSION=' + s.version.to_s +
      ' FIRAuth_MINOR_VERSION=' + s.version.to_s.split(".")[0] + "." + s.version.to_s.split(".")[1]
  }
  s.framework = 'Security'
  s.ios.framework = 'SafariServices'
  s.dependency 'FirebaseAuthInterop', '~> 1.0'
  s.dependency 'FirebaseCore', '~> 6.2'
  s.dependency 'GoogleUtilities/AppDelegateSwizzler', '~> 6.2'
  s.dependency 'GoogleUtilities/Environment', '~> 6.2'
  s.dependency 'GTMSessionFetcher/Core', '~> 1.1'

  s.test_spec 'unit' do |unit_tests|
    unit_tests.platforms = {:ios => '8.0', :osx => '10.11', :tvos => '10.0'}
    unit_tests.source_files = 'Example/Auth/Tests/*.[mh]'
    unit_tests.osx.exclude_files = [
      'Example/Auth/Tests/FIRAuthAPNSTokenManagerTests.m',
      'Example/Auth/Tests/FIRAuthAPNSTokenTests.m',
      'Example/Auth/Tests/FIRAuthAppCredentialManagerTests.m',
      'Example/Auth/Tests/FIRAuthNotificationManagerTests.m',
      'Example/Auth/Tests/FIRAuthURLPresenterTests.m',
      'Example/Auth/Tests/FIREmailLink*',
      'Example/Auth/Tests/FIRPhoneAuthProviderTests.m',
      'Example/Auth/Tests/FIRSendVerificationCode*',
      'Example/Auth/Tests/FIRSignInWithGameCenterTests.m',
      'Example/Auth/Tests/FIRVerifyClient*',
      'Example/Auth/Tests/FIRVerifyPhoneNumber*',
      'Example/Auth/Tests/FIROAuthProviderTests.m',
    ]
    unit_tests.tvos.exclude_files = [
      'Example/Auth/Tests/FIRAuthAPNSTokenManagerTests.m',
      'Example/Auth/Tests/FIRAuthNotificationManagerTests.m',
      'Example/Auth/Tests/FIRAuthURLPresenterTests.m',
      'Example/Auth/Tests/FIREmailLink*',
      'Example/Auth/Tests/FIRPhoneAuthProviderTests.m',
      'Example/Auth/Tests/FIRSendVerificationCode*',
      'Example/Auth/Tests/FIRSignInWithGameCenterTests.m',
      'Example/Auth/Tests/FIRVerifyClient*',
      'Example/Auth/Tests/FIRVerifyPhoneNumber*',
      'Example/Auth/Tests/FIROAuthProviderTests.m',
    ]
    # app_host is needed for tests with keychain
    unit_tests.requires_app_host = true
    unit_tests.pod_target_xcconfig = {
      # Unit tests do library imports using Firebase/Auth/Source recursive relative paths.
      'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}"/Firebase/Auth/Source/**',
    }
    unit_tests.dependency 'OCMock'
  end
end
