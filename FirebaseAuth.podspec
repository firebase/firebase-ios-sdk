Pod::Spec.new do |s|
  s.name             = 'FirebaseAuth'
  s.version          = '5.0.2'
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
  s.osx.deployment_target = '10.10'
  s.tvos.deployment_target = '10.0'

  s.cocoapods_version = '>= 1.4.0'
  s.static_framework = true
  s.prefix_header_file = false

  source = 'Firebase/Auth/Source/'
  s.source_files = source + '**/*.[mh]'
  s.osx.exclude_files = [
    source + '**/FIRAuthAppDelegateProxy.[mh]',
    source + '**/FIRAuthNotificationManager.[mh]',
    source + '**/FIRAuthAppCredentialManager.[mh]',
    source + '**/FIRAuthAPNSTokenManager.[mh]',
    source + '**/FIRAuthAPNSTokenType.[mh]',
    source + '**/FIRAuthAPNSToken.[mh]',
    source + '**/FIRAuthDefaultUIDelegate.[mh]',
    source + '**/FIRAuthUIDelegate.h',
    source + '**/FIRAuthURLPresenter.[mh]',
    source + '**/FIRAuthWebView.[mh]',
    source + '**/FIRAuthWebViewController.[mh]',
    source + '**/FIRPhoneAuthCredential.[mh]',
    source + '**/FIRPhoneAuthProvider.[mh]'
  ]
  s.tvos.exclude_files = [
    source + '**/FIRAuthURLPresenter.[mh]',
    source + '**/FIRAuthWebView.[mh]',
    source + '**/FIRAuthWebViewController.[mh]',
    source + '**/FIRPhoneAuthCredential.[mh]',
    source + '**/FIRPhoneAuthProvider.[mh]'
  ]
  s.public_header_files = source + 'Public/*.h'
  s.preserve_paths = [
    'Firebase/Auth/README.md',
    'Firebase/Auth/CHANGELOG.md'
  ]
  s.pod_target_xcconfig = {
    'GCC_PREPROCESSOR_DEFINITIONS' =>
      'FIRAuth_VERSION=' + s.version.to_s +
      ' FIRAuth_MINOR_VERSION=' + s.version.to_s.split(".")[0] + "." + s.version.to_s.split(".")[1]
  }
  s.framework = 'SafariServices'
  s.framework = 'Security'
  s.dependency 'FirebaseAuthInterop', '~> 1.0'
  s.dependency 'FirebaseCore', '~> 5.0'
  s.dependency 'GoogleUtilities/Environment', '~> 5.0'
  s.dependency 'GTMSessionFetcher/Core', '~> 1.1'
end
