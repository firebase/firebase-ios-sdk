#
# Be sure to run `pod lib lint FirebaseEncoderSwift.podspec' to ensure this is a
# valid spec before submitting.
#

Pod::Spec.new do |s|
  s.name                    = 'FirebaseEncoderSwift'
  s.version                 = '0.0.1-beta'
  s.summary                 = 'Swift Extensions that provides Codable support for the Firebase SDKs'

  s.description      = <<-DESC
FirebaseEncoderSwift is used to serialize custom objects in the Realtime Database, Cloud Firestore and Cloud Functions SDKs.
                       DESC

  s.homepage                = 'https://developers.google.com/'
  s.license                 = { :type => 'Apache', :file => 'LICENSE' }
  s.authors                 = 'Google, Inc.'

  s.source                  = {
    :git => 'https://github.com/Firebase/firebase-ios-sdk.git',
    :tag => 'CocoaPods-' + s.version.to_s
  }

  s.swift_version           = '5.3'
  s.ios.deployment_target   = '11.0'
  s.osx.deployment_target   = '10.12'
  s.tvos.deployment_target  = '11.0'

  s.cocoapods_version       = '>= 1.4.0'
  s.prefix_header_file      = false

  s.requires_arc            = true
  s.source_files = [
    'FirebaseSharedSwift/Sources/third_party/StructureEncoder/*.swift',
  ]
end
