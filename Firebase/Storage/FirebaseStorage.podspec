# This podspec is not intended to be deployed. It is solely for the static
# library framework build process at
# https://github.com/firebase/firebase-ios-sdk/tree/master/BuildFrameworks

Pod::Spec.new do |s|
  s.name             = 'FirebaseStorage'
  s.version          = '2.0.0'
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

  s.source_files = '**/*.[mh]'
  s.public_header_files =
    'FirebaseStorage.h',
    'FIRStorage.h',
    'FIRStorageConstants.h',
    'FIRStorageDownloadTask.h',
    'FIRStorageMetadata.h',
    'FIRStorageObservableTask.h',
    'FIRStorageReference.h',
    'FIRStorageSwiftNameSupport.h',
    'FIRStorageTask.h',
    'FIRStorageTaskSnapshot.h',
    'FIRStorageUploadTask.h'

  s.framework = 'MobileCoreServices'
#    s.dependency 'FirebaseDev/Core'
  s.dependency 'GTMSessionFetcher/Core', '~> 1.1'
  s.xcconfig = { 'GCC_PREPROCESSOR_DEFINITIONS' =>
    '$(inherited) ' +
    'FIRStorage_VERSION=' + s.version.to_s }
end
