#
# Be sure to run `pod lib lint FirebaseFirestoreSwift.podspec' to ensure this is a
# valid spec before submitting.
#

Pod::Spec.new do |s|
  s.name                    = 'FirebaseFirestoreSwift'
  s.version                 = '0.2'
  s.summary                 = 'Swift Extensions for Google Cloud Firestore'

  s.description      = <<-DESC
Google Cloud Firestore is a NoSQL document database built for automatic scaling, high performance, and ease of application development.
                       DESC

  s.homepage                = 'https://developers.google.com/'
  s.license                 = { :type => 'Apache', :file => 'LICENSE' }
  s.authors                 = 'Google, Inc.'

  s.source                  = {
    :git => 'https://github.com/Firebase/firebase-ios-sdk.git',
    :tag => 'FirestoreSwift-' + s.version.to_s
  }

  s.swift_version           = '4.0'
  s.ios.deployment_target   = '8.0'
  s.osx.deployment_target   = '10.11'
  s.tvos.deployment_target  = '10.0'

  s.cocoapods_version       = '>= 1.4.0'
  s.static_framework        = true
  s.prefix_header_file      = false

  s.requires_arc            = true
  s.source_files = [
    'Firestore/Swift/Source/**/*.swift',
    'Firestore/third_party/FirestoreEncoder/*.swift',
  ]

  s.dependency 'FirebaseFirestore', '~> 1.6', '>= 1.6.1'
  s.dependency 'GoogleTest', '1.10.0'

  s.test_spec 'unit' do |int_tests|
    int_tests.source_files = 'Firestore/Swift/Tests/API/*.swift',
                             'Firestore/Swift/Tests/Codable/*.swift',
                             'Firestore/Example/Tests/API/FSTAPIHelpers.*',
                             'Firestore/Example/Tests/Util/FSTHelpers.*'
    int_tests.requires_app_host = true

      abseil_version = '0.20200225.0'
  int_tests.dependency 'abseil/algorithm', abseil_version
  int_tests.dependency 'abseil/base', abseil_version
  int_tests.dependency 'abseil/memory', abseil_version
  int_tests.dependency 'abseil/meta', abseil_version
  int_tests.dependency 'abseil/strings/strings', abseil_version
  int_tests.dependency 'abseil/time', abseil_version
  int_tests.dependency 'abseil/types', abseil_version

    int_tests.pod_target_xcconfig = {
      'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}"',
      'SWIFT_OBJC_BRIDGING_HEADER' => '$(PODS_TARGET_SRCROOT)/Firestore/Swift/Tests/BridgingHeader.h'
    }
  end
end
