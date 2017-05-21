# This podspec is not intended to be deployed. It is solely for the static
# library framework build process at
# https://github.com/firebase/firebase-ios-sdk/tree/master/BuildFrameworks

Pod::Spec.new do |s|
  s.name             = 'FirebaseDatabase'
  s.version          = '4.0.1'
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

  eitherSource = lambda { |paths|
    Array(paths).map { |path| ['Firebase/Database/Source/' + path, 'Source/' + path] }.flatten
  }

  s.source_files = eitherSource[['Api/*.h', 'FIRDatabaseReference.h']]

  # Necessary hack to appease header visibility while as a direct OR transitive/internal dependency
  s.subspec 'Internal' do |ss|
    ss.source_files = eitherSource['**/*.{m,h,mm,c,cpp}']
    ss.private_header_files = eitherSource['**/*.h']
  end

  s.library = 'c++'
  s.library = 'icucore'
  s.framework = 'CFNetwork'
  s.framework = 'Security'
  s.framework = 'SystemConfiguration'
  s.dependency 'leveldb-library'
  s.dependency 'FirebaseCore', '~> 4.0.1'

  s.xcconfig = { 'GCC_PREPROCESSOR_DEFINITIONS' =>
    '$(inherited) ' +
    'FIRDatabase_VERSION=' + s.version.to_s }
end
