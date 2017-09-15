Pod::Spec.new do |s|
  s.name             = 'FirebaseCommunity'
  s.version          = '0.1.1'
  s.summary          = 'Firebase Open Source Libraries for iOS.'

  s.description      = <<-DESC
Firebase Development CocoaPod including experimental and community supported features.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  # NOTE that the FirebaseCommunity pod is NOT yet interchangeable with the Firebase pod
  s.source           = { :git => 'https://github.com/firebase/firebase-ios-sdk.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/Firebase'
  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.10'
  s.default_subspec  = 'Root'
  s.preserve_paths = 'README.md'
  s.module_map = 'Firebase/Firebase/module.modulemap'

  s.subspec 'Root' do |sp|
    sp.source_files = 'Firebase/Firebase/FirebaseCommunity.h'
    sp.public_header_files = 'Firebase/Firebase/FirebaseCommunity.h'
  end

  s.subspec 'Core' do |sp|
    sp.source_files = 'Firebase/Core/**/*.[mh]'
    sp.public_header_files = 'Firebase/Core/Public/*.h','Firebase/Core/Private/*.h',
    sp.private_header_files = 'Firebase/Core/Private/*.h'
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
      'Firebase/Auth/Source/**/FIRAuthDefaultUIDelegate.[mh]',
      'Firebase/Auth/Source/**/FIRAuthUIDelegate.h',
      'Firebase/Auth/Source/**/FIRAuthURLPresenter.[mh]',
      'Firebase/Auth/Source/**/FIRAuthWebView.[mh]',
      'Firebase/Auth/Source/**/FIRAuthWebViewController.[mh]',
      'Firebase/Auth/Source/**/FIRPhoneAuthCredential.[mh]',
      'Firebase/Auth/Source/**/FIRPhoneAuthProvider.[mh]'
    sp.public_header_files = 'Firebase/Auth/Source/Public/*.h'
    sp.preserve_paths =
      'Firebase/Auth/README.md',
      'Firebase/Auth/CHANGELOG.md'
    sp.xcconfig = { 'OTHER_CFLAGS' => '-DFIRAuth_VERSION=' + s.version.to_s +
      ' -DFIRAuth_MINOR_VERSION=' + s.version.to_s.split(".")[0] + "." + s.version.to_s.split(".")[1]
    }
    sp.framework = 'SafariServices'
    sp.framework = 'Security'
    sp.dependency 'FirebaseCommunity/Core'
    sp.dependency 'GTMSessionFetcher/Core', '~> 1.1'
    sp.dependency 'GoogleToolboxForMac/NSDictionary+URLArguments', '~> 2.1'
  end

  s.subspec 'Database' do |sp|
    sp.source_files = 'Firebase/Database/**/*.[mh]',
      'Firebase/Database/third_party/Wrap-leveldb/APLevelDB.mm',
      'Firebase/Database/third_party/SocketRocket/fbase64.c'
    sp.public_header_files = 'Firebase/Database/Public/*.h'
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

    sp.public_header_files = 'Firebase/Messaging/Public/*.h'
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
    sp.public_header_files = 'Firebase/Storage/Public/*.h'
    sp.ios.framework = 'MobileCoreServices'
    sp.osx.framework = 'CoreServices'
    sp.dependency 'FirebaseCommunity/Core'
    sp.dependency 'GTMSessionFetcher/Core', '~> 1.1'
    sp.xcconfig = { 'OTHER_CFLAGS' => '-DFIRStorage_VERSION=' + s.version.to_s }
  end
end
