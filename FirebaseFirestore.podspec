#
# Be sure to run `pod lib lint FirebaseFirestore.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'FirebaseFirestore'
  s.version          = '0.9.3'
  s.summary          = 'Google Cloud Firestore for iOS'

  s.description      = <<-DESC
Google Cloud Firestore is a NoSQL document database built for automatic scaling, high performance, and ease of application development.
                       DESC

  s.homepage         = 'https://developers.google.com/'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = { :git => 'https://github.com/TBD/Firestore.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '7.0'

  s.cocoapods_version = '>= 1.4.0.beta.2'
  s.static_framework = true
  s.prefix_header_file = false

  s.source_files = [
    'Firestore/Source/**/*',
    'Firestore/Port/**/*',
    'Firestore/Protos/objc/**/*.[hm]',
    'Firestore/core/src/**/*.{h,cc}',
    'Firestore/third_party/Immutable/*.[mh]'
  ]
  s.requires_arc = [
    'Firestore/Source/**/*',
    'Firestore/third_party/Immutable/*.[mh]'
  ]
  s.exclude_files = [
    'Firestore/Port/*test.cc',
    'Firestore/third_party/Immutable/Tests/**'
  ]
  s.public_header_files = 'Firestore/Source/Public/*.h'

  s.ios.dependency 'FirebaseAnalytics', '~> 4.0'
  s.dependency 'FirebaseCore', '~> 4.0'
  s.dependency 'gRPC-ProtoRPC', '~> 1.0'
  s.dependency 'leveldb-library', '~> 1.18'
  s.dependency 'Protobuf', '~> 3.1'

  s.frameworks = 'MobileCoreServices'
  s.library = 'c++'
  s.pod_target_xcconfig = {
    'GCC_PREPROCESSOR_DEFINITIONS' =>
      'GPB_USE_PROTOBUF_FRAMEWORK_IMPORTS=1 ',
      'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}"',
      'OTHER_CFLAGS' => '-DFIRFirestore_VERSION=' + s.version.to_s
  }
end
