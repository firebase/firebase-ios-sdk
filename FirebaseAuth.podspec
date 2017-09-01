# This podspec is not intended to be deployed. It is solely for the static
# library framework build process at
# https://github.com/firebase/firebase-ios-sdk/tree/master/BuildFrameworks

Pod::Spec.new do |s|
  s.name             = 'FirebaseAuth'
  s.version          = '0.0.4'
  s.summary          = 'Firebase Open Source Libraries for iOS.'

  s.description      = <<-DESC
Simplify your iOS development, grow your user base, and monetize more effectively with Firebase.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = { :git => 'https://github.com/firebase/firebase-ios-sdk.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/Firebase'
  s.ios.deployment_target = '7.0'
  s.osx.deployment_target = '10.10'
  s.static_framework = true

  s.source_files = 'Firebase/Auth/**/*.[mh]'
  s.osx.exclude_files =
    'Firebase/Auth/Source/**/FIRAuthAppDelegateProxy.[mh]',
    'Firebase/Auth/Source/**/FIRAuthNotificationManager.[mh]',
    'Firebase/Auth/Source/**/FIRAuthAppCredentialManager.[mh]',
    'Firebase/Auth/Source/**/FIRAuthAPNSTokenManager.[mh]',
    'Firebase/Auth/Source/**/FIRAuthAPNSTokenType.[mh]',
    'Firebase/Auth/Source/**/FIRAuthAPNSToken.[mh]',
    'Firebase/Auth/Source/**/FIRPhoneAuthCredential.[mh]',
    'Firebase/Auth/Source/**/FIRPhoneAuthProvider.[mh]'
  s.public_header_files = 'Firebase/Auth/Source/Public/*.h'
  s.preserve_paths =
    'Firebase/Auth/README.md',
    'Firebase/Auth/CHANGELOG.md'
  s.xcconfig = { 'GCC_PREPROCESSOR_DEFINITIONS' =>
    'FIRAuth_VERSION=' + s.version.to_s +
    ' FIRAuth_MINOR_VERSION=' + s.version.to_s.split(".")[0] + "." + s.version.to_s.split(".")[1]
  }
  s.framework = 'Security'
  s.dependency 'FirebaseCore'
  s.ios.dependency 'FirebaseAnalytics'
  s.dependency 'GTMSessionFetcher/Core', '~> 1.1'
  s.dependency 'GoogleToolboxForMac/NSDictionary+URLArguments', '~> 2.1'

  # Include FirebaseCore's GTM dependency to workaround
  # https://github.com/CocoaPods/CocoaPods/issues/6967
  s.dependency 'GoogleToolboxForMac/NSData+zlib', '~> 2.1'
end
