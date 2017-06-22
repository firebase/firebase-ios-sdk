# This podspec is not intended to be deployed. It is solely for the static
# library framework build process at
# https://github.com/firebase/firebase-ios-sdk/tree/master/BuildFrameworks

Pod::Spec.new do |s|
  s.name             = 'FirebaseMessaging'
  s.version          = '2.0.0'
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

  s.source_files = '**/*.[mh]'
  s.requires_arc = '*.m'
  s.public_header_files =
      'Public/FirebaseMessaging.h',
      'Public/FIRMessaging.h'

  s.library = 'sqlite3'
  s.xcconfig = { 'GCC_PREPROCESSOR_DEFINITIONS' =>
    '$(inherited) ' +
    'GPB_USE_PROTOBUF_FRAMEWORK_IMPORTS=1 ' +
    'FIRMessaging_LIB_VERSION=' + String(s.version)
  }
  s.framework = 'AddressBook'
  s.framework = 'SystemConfiguration'
#  s.dependency 'FirebaseCommunity/Core'
  s.dependency 'GoogleToolboxForMac/Logger', '~> 2.1'
  s.dependency 'Protobuf', '~> 3.1'
end
