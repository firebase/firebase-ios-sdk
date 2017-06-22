# This podspec is not intended to be deployed. It is solely for the static
# library framework build process at
# https://github.com/firebase/firebase-ios-sdk/tree/master/BuildFrameworks

Pod::Spec.new do |s|
  s.name             = 'FirebaseAuth'
  s.version          = '4.0.0'
  s.summary          = 'Firebase Open Source Libraries for iOS.'

  s.description      = <<-DESC
Simplify your iOS development, grow your user base, and monetize more effectively with Firebase.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache', :file => '../../LICENSE' }
  s.authors          = 'Google, Inc.'

  # NOTE that the FirebaseCommunity pod is neither publicly deployed nor yet interchangeable with the
  # Firebase pod
  s.source           = { :git => 'https://github.com/firebase/firebase-ios-sdk.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/Firebase'
  s.ios.deployment_target = '7.0'
  s.osx.deployment_target = '10.10'

  s.source_files = '**/*.[mh]'
  s.osx.exclude_files =
    'Source/**/FIRAuthAppDelegateProxy.[mh]',
    'Source/**/FIRAuthNotificationManager.[mh]',
    'Source/**/FIRAuthAppCredentialManager.[mh]',
    'Source/**/FIRAuthAPNSTokenManager.[mh]',
    'Source/**/FIRAuthAPNSTokenType.[mh]',
    'Source/**/FIRAuthAPNSToken.[mh]',
    'Source/**/FIRPhoneAuthProvider.[mh]'
  s.public_header_files =
    'Source/FirebaseAuth.h',
    'Source/FirebaseAuthVersion.h',
    'Source/FIRAdditionalUserInfo.h',
    'Source/FIRAuth.h',
    'Source/FIRAuthAPNSTokenType.h',
    'Source/FIRAuthCredential.h',
    'Source/FIRAuthDataResult.h',
    'Source/FIRAuthErrors.h',
    'Source/FIRAuthSwiftNameSupport.h',
    'Source/AuthProviders/EmailPassword/FIREmailAuthProvider.h',
    'Source/AuthProviders/Facebook/FIRFacebookAuthProvider.h',
    'Source/AuthProviders/GitHub/FIRGitHubAuthProvider.h',
    'Source/AuthProviders/Google/FIRGoogleAuthProvider.h',
    'Source/AuthProviders/OAuth/FIROAuthProvider.h',
    'Source/AuthProviders/Phone/FIRPhoneAuthCredential.h',
    'Source/AuthProviders/Phone/FIRPhoneAuthProvider.h',
    'Source/AuthProviders/Twitter/FIRTwitterAuthProvider.h',
    'Source/FIRUser.h',
    'Source/FIRUserInfo.h'
  s.preserve_paths =
    'README.md',
    'CHANGELOG.md'
  s.xcconfig = { 'GCC_PREPROCESSOR_DEFINITIONS' =>
    '$(inherited) ' + 'FIRAuth_VERSION=' + s.version.to_s +
    ' FIRAuth_MINOR_VERSION=' + s.version.to_s.split(".")[0] + "." + s.version.to_s.split(".")[1]
  }
  s.framework = 'Security'
#  s.dependency 'FirebaseCommunity/Core'
  s.dependency 'GTMSessionFetcher/Core', '~> 1.1'
  s.dependency 'GoogleToolboxForMac/NSDictionary+URLArguments', '~> 2.1'
end
