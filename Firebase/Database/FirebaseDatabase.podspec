# This podspec is not intended to be deployed. It is solely for the static
# library framework build process at
# https://github.com/firebase/firebase-ios-sdk/tree/master/BuildFrameworks

Pod::Spec.new do |s|
  s.name             = 'FirebaseDatabase'
  s.version          = '4.0.0'
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

  s.source_files =  '**/*.[mh]',
    'third_party/Wrap-leveldb/APLevelDB.mm',
    'third_party/SocketRocket/fbase64.c'
  s.public_header_files =
    'Api/FirebaseDatabase.h',
    'Api/FIRDataEventType.h',
    'Api/FIRDataSnapshot.h',
    'Api/FIRDatabaseQuery.h',
    'Api/FIRDatabaseSwiftNameSupport.h',
    'Api/FIRMutableData.h',
    'Api/FIRServerValue.h',
    'Api/FIRTransactionResult.h',
    'Api/FIRDatabase.h',
    'FIRDatabaseReference.h'
  s.library = 'c++'
  s.library = 'icucore'
  s.framework = 'CFNetwork'
  s.framework = 'Security'
  s.framework = 'SystemConfiguration'
  s.dependency 'leveldb-library'
#  s.dependency 'FirebaseDev/Core'
  s.xcconfig = { 'GCC_PREPROCESSOR_DEFINITIONS' =>
    '$(inherited) ' +
    'FIRDatabase_VERSION=' + s.version.to_s }
end
