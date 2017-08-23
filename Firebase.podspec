Pod::Spec.new do |s|
  s.name             = 'Firebase'
  s.version          = '0.0.7'
  s.summary          = 'Firebase Open Source Libraries for iOS.'

  s.description      = <<-DESC
Firebase Development CocoaPod including experimental and community supported features.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = { :git => 'https://github.com/firebase/firebase-ios-sdk.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/Firebase'
  s.ios.deployment_target = '7.0'
  s.osx.deployment_target = '10.10'
  s.default_subspec  = 'Root'

  s.static_framework = true

  s.preserve_paths = 'README.md'
  s.preserve_paths = 'Firebase/Firebase/module.modulemap'

  #s.module_map = 'Firebase/Firebase/module.modulemap'
#
  s.subspec 'Root' do |sp|

  #  sp.public_header_files = 'Firebase/Firebase/Firebase.h'
    sp.preserve_paths = 'README.md'
    sp.preserve_paths = 'Firebase/Firebase/Firebase.h'
    sp.ios.dependency 'FirebaseAnalytics'
    sp.dependency 'FirebaseCore'
    sp.user_target_xcconfig = { 'HEADER_SEARCH_PATHS' =>
      '$(inherited) ${PODS_ROOT}/Firebase/Firebase/Firebase'
    }
  end

  s.subspec 'Core' do |sp|
    sp.dependency 'Firebase/Root'
    sp.dependency 'FirebaseCore'
  end

  s.subspec 'Auth' do |sp|
    sp.dependency 'Firebase/Root'
    sp.dependency 'FirebaseAuth'
  end
#
#  s.subspec 'Database' do |sp|
#    sp.source_files = 'Firebase/Database/**/*.[mh]',
#      'Firebase/Database/third_party/Wrap-leveldb/APLevelDB.mm',
#      'Firebase/Database/third_party/SocketRocket/fbase64.c'
#    sp.public_header_files = 'Firebase/Database/Public/*.h'
#    sp.library = 'c++'
#    sp.library = 'icucore'
#    sp.framework = 'CFNetwork'
#    sp.framework = 'Security'
#    sp.framework = 'SystemConfiguration'
#    sp.dependency 'leveldb-library'
#    sp.dependency 'FirebaseCommunity/Core'
#    sp.xcconfig = { 'OTHER_CFLAGS' => '-DFIRDatabase_VERSION=' + s.version.to_s }
#  end
#
#  s.subspec 'Messaging' do |sp|
#    sp.platform = 'ios'
#    sp.source_files = 'Firebase/Messaging/**/*.[mh]'
#    sp.requires_arc = 'Firebase/Messaging/*.m'
#
#    sp.public_header_files = 'Firebase/Messaging/Public/*.h'
#    sp.library = 'sqlite3'
#    sp.xcconfig ={ 'GCC_PREPROCESSOR_DEFINITIONS' =>
#      '$(inherited) ' +
#      'GPB_USE_PROTOBUF_FRAMEWORK_IMPORTS=1 ' +
#      'FIRMessaging_LIB_VERSION=' + String(s.version)
#    }
#    sp.framework = 'AddressBook'
#    sp.framework = 'SystemConfiguration'
#    sp.dependency 'FirebaseCommunity/Core'
#    sp.dependency 'GoogleToolboxForMac/Logger', '~> 2.1'
#    sp.dependency 'Protobuf', '~> 3.1'
#  end
#
#  s.subspec 'Storage' do |sp|
#    sp.source_files = 'Firebase/Storage/**/*.[mh]'
#    sp.public_header_files = 'Firebase/Storage/Public/*.h'
#    sp.ios.framework = 'MobileCoreServices'
#    sp.osx.framework = 'CoreServices'
#    sp.dependency 'FirebaseCore'
#    sp.dependency 'GTMSessionFetcher/Core', '~> 1.1'
#    sp.xcconfig = { 'OTHER_CFLAGS' => '-DFIRStorage_VERSION=' + s.version.to_s }
#  end
end
