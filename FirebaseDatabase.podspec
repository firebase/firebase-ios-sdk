# This podspec is not intended to be deployed. It is solely for the static
# library framework build process at
# https://github.com/firebase/firebase-ios-sdk/tree/master/BuildFrameworks

Pod::Spec.new do |s|
  s.name             = 'FirebaseDatabase'
  s.version          = '0.0.1'
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

  s.cocoapods_version = '>= 1.4.0.beta.1'
  s.static_framework = true
  s.prefix_header_file = false

  base_dir = "Firebase/Database/"
  s.source_files = base_dir + '**/*.[mh]',
    base_dir + 'third_party/Wrap-leveldb/APLevelDB.mm',
    base_dir + 'third_party/SocketRocket/fbase64.c'
  s.public_header_files = base_dir + 'Public/*.h'
  s.libraries = ['c++', 'icucore']
  s.frameworks = ['CFNetwork', 'Security', 'SystemConfiguration']
  s.dependency 'leveldb-library', '~> 1.18'
  s.dependency 'FirebaseCore', '~> 4.0'
  s.ios.dependency 'FirebaseAnalytics', '~> 4.0'
  s.ios.dependency 'FirebaseCoreDiagnostics'
  s.pod_target_xcconfig = { 'GCC_PREPROCESSOR_DEFINITIONS' =>
    'FIRDatabase_VERSION=' + s.version.to_s }
end
