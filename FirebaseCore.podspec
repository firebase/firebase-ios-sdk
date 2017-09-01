# This podspec is not intended to be deployed. It is solely for the static
# library framework build process at
# https://github.com/firebase/firebase-ios-sdk/tree/master/BuildFrameworks

Pod::Spec.new do |s|
  s.name             = 'FirebaseCore'
  s.version          = '0.0.8'
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
#  s.cocoapods_version = '>= 1.4.0'
  s.static_framework = true

  base_dir = "Firebase/Core/"
  s.source_files = base_dir + '**/*.[mh]'
  s.public_header_files = base_dir + 'Public/*.h', base_dir + 'Private/*.h'
  s.private_header_files = base_dir + 'Private/*.h'
  s.dependency 'GoogleToolboxForMac/NSData+zlib', '~> 2.1'

  # TODO - Workaround fill in bug number
  s.dependency 'GoogleToolboxForMac/NSDictionary+URLArguments', '~> 2.1'
end
