Pod::Spec.new do |s|
  s.name             = 'FirebaseCommunity'
  s.version          = '0.0.1'
  s.summary          = 'Firebase Open Source Libraries for iOS.'

  s.description      = <<-DESC
Firebase Development CocoaPod including experimental and community supported features.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  # NOTE that the FirebaseCommunity pod is neither publicly deployed nor yet interchangeable with the
  # Firebase pod
  s.source           = { :git => 'https://github.com/firebase/firebase-ios-sdk.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/Firebase'
  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.10'
  s.default_subspec  = 'Root'
  s.preserve_paths = 'README.md'

  s.subspec 'Root' do |sp|
    sp.source_files = 'Firebase/Firebase/Firebase.h'
    sp.public_header_files = 'Firebase/Firebase/Firebase.h'
    sp.user_target_xcconfig = { 'HEADER_SEARCH_PATHS' => '$(inherited) "${PODS_ROOT}/Firebase/Firebase/Firebase"' }
  end

  s.subspec 'Core' do |sp|
    sp.source_files = 'Firebase/Core/**/*.[mh]'
    sp.public_header_files =
      'Firebase/Core/FirebaseCore.h',
      'Firebase/Core/FIRAnalyticsConfiguration.h',
      'Firebase/Core/FIRApp.h',
      'Firebase/Core/FIRConfiguration.h',
      'Firebase/Core/FIRLoggerLevel.h',
      'Firebase/Core/FIROptions.h',
      'Firebase/Core/FIRCoreSwiftNameSupport.h'
    sp.dependency 'GoogleToolboxForMac/NSData+zlib', '~> 2.1'
    sp.dependency 'FirebaseCommunity/Root'
  end

  s.subspec 'Auth' do |sp|
    sp.source_files = 'Firebase/Auth/Source/**/*.[mh]'
    sp.osx.exclude_files =
      'Firebase/Auth/Source/**/FIRAuthAppDelegateProxy.[mh]',
      'Firebase/Auth/Source/**/FIRAuthNotificationManager.[mh]',
      'Firebase/Auth/Source/**/FIRAuthAppCredentialManager.[mh]',
      'Firebase/Auth/Source/**/FIRAuthAPNSTokenManager.[mh]',
      'Firebase/Auth/Source/**/FIRAuthAPNSTokenType.[mh]',
      'Firebase/Auth/Source/**/FIRAuthAPNSToken.[mh]',
      'Firebase/Auth/Source/**/FIRPhoneAuthProvider.[mh]'
    sp.public_header_files =
      'Firebase/Auth/Source/FirebaseAuth.h',
      'Firebase/Auth/Source/FirebaseAuthVersion.h',
      'Firebase/Auth/Source/FIRAdditionalUserInfo.h',
      'Firebase/Auth/Source/FIRAuth.h',
      'Firebase/Auth/Source/FIRAuthAPNSTokenType.h',
      'Firebase/Auth/Source/FIRAuthCredential.h',
      'Firebase/Auth/Source/FIRAuthDataResult.h',
      'Firebase/Auth/Source/FIRAuthErrors.h',
      'Firebase/Auth/Source/FIRAuthSwiftNameSupport.h',
      'Firebase/Auth/Source/AuthProviders/EmailPassword/FIREmailAuthProvider.h',
      'Firebase/Auth/Source/AuthProviders/Facebook/FIRFacebookAuthProvider.h',
      'Firebase/Auth/Source/AuthProviders/GitHub/FIRGitHubAuthProvider.h',
      'Firebase/Auth/Source/AuthProviders/Google/FIRGoogleAuthProvider.h',
      'Firebase/Auth/Source/AuthProviders/OAuth/FIROAuthProvider.h',
      'Firebase/Auth/Source/AuthProviders/Phone/FIRPhoneAuthCredential.h',
      'Firebase/Auth/Source/AuthProviders/Phone/FIRPhoneAuthProvider.h',
      'Firebase/Auth/Source/AuthProviders/Twitter/FIRTwitterAuthProvider.h',
      'Firebase/Auth/Source/FIRUser.h',
      'Firebase/Auth/Source/FIRUserInfo.h'
    sp.preserve_paths =
      'Firebase/Auth/README.md',
      'Firebase/Auth/CHANGELOG.md'
    sp.xcconfig = { 'OTHER_CFLAGS' => '-DFIRAuth_VERSION=' + s.version.to_s +
      ' -DFIRAuth_MINOR_VERSION=' + s.version.to_s.split(".")[0] + "." + s.version.to_s.split(".")[1]
    }
    sp.framework = 'Security'
    sp.dependency 'FirebaseCommunity/Core'
    sp.dependency 'GTMSessionFetcher/Core', '~> 1.1'
    sp.dependency 'GoogleToolboxForMac/NSDictionary+URLArguments', '~> 2.1'
  end

  s.subspec 'Database' do |sp|
    sp.source_files = 'Firebase/Database/**/*.[mh]',
      'Firebase/Database/third_party/Wrap-leveldb/APLevelDB.mm',
      'Firebase/Database/third_party/SocketRocket/fbase64.c'
    sp.public_header_files =
      'Firebase/Database/Api/FirebaseDatabase.h',
      'Firebase/Database/Api/FIRDataEventType.h',
      'Firebase/Database/Api/FIRDataSnapshot.h',
      'Firebase/Database/Api/FIRDatabaseQuery.h',
      'Firebase/Database/Api/FIRDatabaseSwiftNameSupport.h',
      'Firebase/Database/Api/FIRMutableData.h',
      'Firebase/Database/Api/FIRServerValue.h',
      'Firebase/Database/Api/FIRTransactionResult.h',
      'Firebase/Database/Api/FIRDatabase.h',
      'Firebase/Database/FIRDatabaseReference.h'
    sp.library = 'c++'
    sp.library = 'icucore'
    sp.framework = 'CFNetwork'
    sp.framework = 'Security'
    sp.framework = 'SystemConfiguration'
    sp.dependency 'leveldb-library'
    sp.dependency 'FirebaseCommunity/Core'
    sp.xcconfig = { 'OTHER_CFLAGS' => '-DFIRDatabase_VERSION=' + s.version.to_s }
  end

  s.subspec 'Messaging' do |sp|
    sp.platform = 'ios'
    sp.source_files = 'Firebase/Messaging/**/*.[mh]'
    sp.requires_arc = 'Firebase/Messaging/*.m'

    sp.public_header_files =
      'Firebase/Messaging/Public/FirebaseMessaging.h',
      'Firebase/Messaging/Public/FIRMessaging.h'
    sp.library = 'sqlite3'
    sp.xcconfig ={ 'GCC_PREPROCESSOR_DEFINITIONS' =>
      '$(inherited) ' +
      'GPB_USE_PROTOBUF_FRAMEWORK_IMPORTS=1 ' +
      'FIRMessaging_LIB_VERSION=' + String(s.version)
    }
    sp.framework = 'AddressBook'
    sp.framework = 'SystemConfiguration'
    sp.dependency 'FirebaseCommunity/Core'
    sp.dependency 'GoogleToolboxForMac/Logger', '~> 2.1'
    sp.dependency 'Protobuf', '~> 3.1'
  end

  s.subspec 'Storage' do |sp|
    sp.source_files = 'Firebase/Storage/**/*.[mh]'
    sp.public_header_files =
      'Firebase/Storage/FirebaseStorage.h',
      'Firebase/Storage/FIRStorage.h',
      'Firebase/Storage/FIRStorageConstants.h',
      'Firebase/Storage/FIRStorageDownloadTask.h',
      'Firebase/Storage/FIRStorageMetadata.h',
      'Firebase/Storage/FIRStorageObservableTask.h',
      'Firebase/Storage/FIRStorageReference.h',
      'Firebase/Storage/FIRStorageSwiftNameSupport.h',
      'Firebase/Storage/FIRStorageTask.h',
      'Firebase/Storage/FIRStorageTaskSnapshot.h',
      'Firebase/Storage/FIRStorageUploadTask.h'
    sp.ios.framework = 'MobileCoreServices'
    sp.osx.framework = 'CoreServices'
    sp.dependency 'FirebaseCommunity/Core'
    sp.dependency 'GTMSessionFetcher/Core', '~> 1.1'
    sp.xcconfig = { 'OTHER_CFLAGS' => '-DFIRStorage_VERSION=' + s.version.to_s }
  end
end
