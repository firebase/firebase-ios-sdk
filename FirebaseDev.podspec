Pod::Spec.new do |s|
  s.name             = 'FirebaseDev'
  s.version          = '4.0.1'
  s.summary          = 'Firebase Open Source Libraries for iOS.'

  s.description      = <<-DESC
Simplify your iOS development, grow your user base, and monetize more effectively with Firebase.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  # NOTE that the FirebaseDev pod is neither publicly deployed nor yet interchangeable with the
  # Firebase pod
  s.source           = { :git => 'https://github.com/firebase/firebase-ios-sdk.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/Firebase'
  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.10'
  s.default_subspec  = 'Root'

  s.subspec 'Root' do |sp|
    sp.source_files = 'Firebase/Firebase/Firebase.h'
    sp.public_header_files = 'Firebase/Firebase/Firebase.h'
    sp.preserve_paths = 'Firebase/Firebase/module.modulemap'
    sp.user_target_xcconfig = { 'HEADER_SEARCH_PATHS' => '$(inherited) "${PODS_ROOT}/Firebase/Firebase/Firebase"' }
  end

  s.subspec 'Core' do |sp|
    sp.source_files = 'Firebase/Core/Source/**/*.[mh]'
    sp.public_header_files =
      'Firebase/Core/Source/FirebaseCore.h',
      'Firebase/Core/Source/FIRAnalyticsConfiguration.h',
      'Firebase/Core/Source/FIRApp.h',
      'Firebase/Core/Source/FIRConfiguration.h',
      'Firebase/Core/Source/FIRLoggerLevel.h',
      'Firebase/Core/Source/FIROptions.h',
      'Firebase/Core/Source/FIRCoreSwiftNameSupport.h'
    sp.dependency 'GoogleToolboxForMac/NSData+zlib', '~> 2.1'
    sp.dependency 'FirebaseDev/Root'
  end

  s.subspec 'Auth' do |sp|
    sp.source_files = 'Firebase/Auth/Source/**/*.[mh]'
    sp.osx.exclude_files =
      'Firebase/Auth/Source/FIRAuthAppDelegateProxy.[mh]',
      'Firebase/Auth/Source/FIRAuthNotificationManager.[mh]',
      'Firebase/Auth/Source/FIRAuthAPNSTokenManager.[mh]',
      'Firebase/Auth/Source/FIRAuthAPNSTokenType.[mh]',
      'Firebase/Auth/Source/FIRAuthAPNSToken.[mh]',
      'Firebase/Auth/Source/AuthProviders/Phone/FIRPhoneAuthProvider.[mh]'
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
    sp.dependency 'FirebaseDev/Core'
    sp.dependency 'GTMSessionFetcher/Core', '~> 1.1'
    sp.dependency 'GoogleToolboxForMac/NSDictionary+URLArguments', '~> 2.1'
  end

  s.subspec 'Database' do |sp|
    sp.source_files = 'Firebase/Database/Source/**/*.[mh]',
      'Firebase/Database/Source/third_party/Wrap-leveldb/APLevelDB.mm',
      'Firebase/Database/Source/third_party/SocketRocket/fbase64.c'
    sp.public_header_files =
      'Firebase/Database/Source/Api/FirebaseDatabase.h',
      'Firebase/Database/Source/Api/FIRDataEventType.h',
      'Firebase/Database/Source/Api/FIRDataSnapshot.h',
      'Firebase/Database/Source/Api/FIRDatabaseQuery.h',
      'Firebase/Database/Source/Api/FIRDatabaseSwiftNameSupport.h',
      'Firebase/Database/Source/Api/FIRMutableData.h',
      'Firebase/Database/Source/Api/FIRServerValue.h',
      'Firebase/Database/Source/Api/FIRTransactionResult.h',
      'Firebase/Database/Source/Api/FIRDatabase.h',
      'Firebase/Database/Source/FIRDatabaseReference.h'
    sp.library = 'c++'
    sp.library = 'icucore'
    sp.framework = 'CFNetwork'
    sp.framework = 'Security'
    sp.framework = 'SystemConfiguration'
    sp.dependency 'leveldb-library'
    sp.dependency 'FirebaseDev/Core'
    sp.xcconfig = { 'OTHER_CFLAGS' => '-DFIRDatabase_VERSION=' + s.version.to_s }
  end

  s.subspec 'Messaging' do |sp|
    sp.platform = 'ios'
    sp.source_files = 'Firebase/Messaging/Source/**/*.[mh]'
    sp.requires_arc = 'Firebase/Messaging/Source/*.m'

    sp.public_header_files =
      'Firebase/Messaging/Source/Public/FirebaseMessaging.h',
      'Firebase/Messaging/Source/Public/FIRMessaging.h'
    sp.library = 'sqlite3'
    sp.xcconfig ={ 'GCC_PREPROCESSOR_DEFINITIONS' =>
      '$(inherited) ' +
      'GPB_USE_PROTOBUF_FRAMEWORK_IMPORTS=1 ' +
      'FIRMessaging_LIB_VERSION=' + String(s.version)
    }
    sp.framework = 'AddressBook'
    sp.framework = 'SystemConfiguration'
    sp.dependency 'FirebaseDev/Core'
    sp.dependency 'GoogleToolboxForMac/Logger', '~> 2.1'
    sp.dependency 'Protobuf', '~> 3.1'
  end

  s.subspec 'Storage' do |sp|
    sp.source_files = 'Firebase/Storage/Source/**/*.[mh]'
    sp.public_header_files =
      'Firebase/Storage/Source/FirebaseStorage.h',
      'Firebase/Storage/Source/FIRStorage.h',
      'Firebase/Storage/Source/FIRStorageConstants.h',
      'Firebase/Storage/Source/FIRStorageDownloadTask.h',
      'Firebase/Storage/Source/FIRStorageMetadata.h',
      'Firebase/Storage/Source/FIRStorageObservableTask.h',
      'Firebase/Storage/Source/FIRStorageReference.h',
      'Firebase/Storage/Source/FIRStorageSwiftNameSupport.h',
      'Firebase/Storage/Source/FIRStorageTask.h',
      'Firebase/Storage/Source/FIRStorageTaskSnapshot.h',
      'Firebase/Storage/Source/FIRStorageUploadTask.h'
    sp.ios.framework = 'MobileCoreServices'
    sp.osx.framework = 'CoreServices'
    sp.dependency 'FirebaseDev/Core'
    sp.dependency 'GTMSessionFetcher/Core', '~> 1.1'
    sp.xcconfig = { 'OTHER_CFLAGS' => '-DFIRStorage_VERSION=' + s.version.to_s }
  end
end
