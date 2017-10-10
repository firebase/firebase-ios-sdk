# This podspec is not intended to be deployed. It is solely for the static
# library framework build process at
# https://github.com/firebase/firebase-ios-sdk/tree/master/BuildFrameworks

Pod::Spec.new do |s|
  s.name             = 'FirebaseAuth'
  s.version          = '4.3.0'
  s.summary          = 'The official iOS client for Firebase Authentication'

  s.description      = <<-DESC
Firebase Authentication allows you to manage your own account system without any backend code. It
supports email and password accounts, as well as several 3rd party authentication mechanisms.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache', :file => '../../LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = { :git => 'https://github.com/firebase/firebase-ios-sdk.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/Firebase'
  s.ios.deployment_target = '7.0'
  s.osx.deployment_target = '10.10'

  s.cocoapods_version = '>= 1.4.0.beta.1'
  s.static_framework = true
  s.prefix_header_file = false

  s.source_files = 'Source/**/*.[mh]'
  s.osx.exclude_files =
    'Source/**/FIRAuthAppDelegateProxy.[mh]',
    'Source/**/FIRAuthNotificationManager.[mh]',
    'Source/**/FIRAuthAppCredentialManager.[mh]',
    'Source/**/FIRAuthAPNSTokenManager.[mh]',
    'Source/**/FIRAuthAPNSTokenType.[mh]',
    'Source/**/FIRAuthAPNSToken.[mh]',
    'Source/**/FIRAuthDefaultUIDelegate.[mh]',
    'Source/**/FIRAuthUIDelegate.h',
    'Source/**/FIRAuthURLPresenter.[mh]',
    'Source/**/FIRAuthWebView.[mh]',
    'Source/**/FIRAuthWebViewController.[mh]',
    'Source/**/FIRPhoneAuthCredential.[mh]',
    'Source/**/FIRPhoneAuthProvider.[mh]'
  s.public_header_files = 'Source/Public/*.h'
  s.preserve_paths =
    'README.md',
    'CHANGELOG.md'
  s.xcconfig = { 'GCC_PREPROCESSOR_DEFINITIONS' =>
    'FIRAuth_VERSION=' + s.version.to_s +
    ' FIRAuth_MINOR_VERSION=' + s.version.to_s.split(".")[0] + "." + s.version.to_s.split(".")[1]
  }
  s.framework = 'SafariServices'
  s.framework = 'Security'
  s.dependency 'FirebaseCore', '~> 4.0'
  s.ios.dependency 'FirebaseCoreDiagnostics'
  s.ios.dependency 'FirebaseAnalytics', '~> 4.0'
  s.dependency 'GTMSessionFetcher/Core', '~> 1.1'
  s.dependency 'GoogleToolboxForMac/NSDictionary+URLArguments', '~> 2.1'
end
