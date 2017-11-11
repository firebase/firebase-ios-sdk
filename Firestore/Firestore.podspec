#
# Be sure to run `pod lib lint Firestore.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'Firestore'
  s.version          = '0.9.2'
  s.summary          = 'Google Cloud Firestore for iOS'

  s.description      = <<-DESC
Google Cloud Firestore is a NoSQL document database built for automatic scaling, high performance, and ease of application development.
                       DESC

  s.homepage         = 'https://developers.google.com/'
  s.license          = { :type => 'Apache', :file => '../LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = { :git => 'https://github.com/TBD/Firestore.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '7.0'

  s.cocoapods_version = '>= 1.4.0.beta.2'
  s.static_framework = true
  s.prefix_header_file = false

  s.source_files = 'Source/**/*', 'Port/**/*', 'Protos/objc/**/*.[hm]', 'third_party/**/*.[mh]'
  s.requires_arc = 'Source/**/*', 'third_party/**/*.[mh]'
  s.exclude_files = 'Port/*test.cc', 'third_party/**/Tests/**'
  s.public_header_files = 'Source/Public/*.h'

  s.ios.dependency 'FirebaseAnalytics'
  s.dependency 'FirebaseAuth'
  s.dependency 'FirebaseCore'
  s.dependency 'gRPC-ProtoRPC'
  s.dependency 'leveldb-library'
  s.dependency 'Protobuf'

  s.frameworks = 'MobileCoreServices'
  s.library = 'c++'

  s.pod_target_xcconfig = {
    'GCC_PREPROCESSOR_DEFINITIONS' =>
    'GPB_USE_PROTOBUF_FRAMEWORK_IMPORTS=1 ',
    'OTHER_CFLAGS' => '-DFIRFirestore_VERSION=' + s.version.to_s
  }
end
