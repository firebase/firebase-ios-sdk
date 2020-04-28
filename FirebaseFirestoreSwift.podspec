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

  s.test_spec 'unit' do |unit_tests|
    # The other Swift tests require FSTDocRef, gtest, and other dependencies.
    unit_tests.source_files = 'Firestore/Swift/Tests/API/*.swift'
  end
end
