# This podspec is not intended to be deployed. It is solely for the static
# library framework build process at
# https://github.com/firebase/firebase-ios-sdk/tree/master/BuildFrameworks

Pod::Spec.new do |s|
  s.name             = 'FirebaseAuth'
  s.version          = '4.1.0'
  s.summary          = 'Firebase Open Source Libraries for iOS.'

  s.description      = <<-DESC
Simplify your iOS development, grow your user base, and monetize more effectively with Firebase.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache', :file => '../../LICENSE' }
  s.authors          = 'Google, Inc.'

  # NOTE that the FirebaseDev pod is neither publicly deployed nor yet interchangeable with the
  # Firebase pod
  s.source           = { :git => 'https://github.com/firebase/firebase-ios-sdk.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/Firebase'
  s.ios.deployment_target = '7.0'
  s.osx.deployment_target = '10.10'

  s.source_files = 'Firebase/Auth/Source/**/*.[mh]', 'Source/**/*.[mh]'
  s.public_header_files =
    '**FirebaseAuth.h',
    '**FirebaseAuthVersion.h',
    '**FIRAdditionalUserInfo.h',
    '**FIRAuth.h',
    '**FIRAuthAPNSTokenType.h',
    '**FIRAuthCredential.h',
    '**FIRAuthDataResult.h',
    '**FIRAuthErrors.h',
    '**FIRAuthSwiftNameSupport.h',
    '**FIREmailAuthProvider.h',
    '**FIRFacebookAuthProvider.h',
    '**FIRGitHubAuthProvider.h',
    '**FIRGoogleAuthProvider.h',
    '**FIROAuthProvider.h',
    '**FIRPhoneAuthCredential.h',
    '**FIRPhoneAuthProvider.h',
    '**FIRTwitterAuthProvider.h',
    '**FIRUser.h',
    '**FIRUserInfo.h'
  s.preserve_paths =
    'README.md',
    'CHANGELOG.md'
  s.xcconfig = { 'GCC_PREPROCESSOR_DEFINITIONS' =>
    '$(inherited) ' + 'FIRAuth_VERSION=' + s.version.to_s +
    ' FIRAuth_MINOR_VERSION=' + s.version.to_s.split(".")[0] + "." + s.version.to_s.split(".")[1]
  }
  s.framework = 'Security'
  s.dependency 'FirebaseCore', '~> 4.1.0'
  s.dependency 'GTMSessionFetcher/Core', '~> 1.1'
  s.dependency 'GoogleToolboxForMac/NSDictionary+URLArguments', '~> 2.1'
end
