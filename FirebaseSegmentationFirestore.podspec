#
# Be sure to run `pod lib lint FirebaseFirestoreSwift.podspec' to ensure this is a
# valid spec before submitting.
#

Pod::Spec.new do |s|
  s.name                    = 'FirebaseSegmentationFirestore'
  s.version                 = '7.1.0-beta'
  s.summary                 = 'Write Segments describing Analytics data via Firestore'

  s.description      = <<-DESC
Write Segments describing Analytics data via Firestore'.
                       DESC

  s.homepage                = 'https://developers.google.com/'
  s.license                 = { :type => 'Apache', :file => 'LICENSE' }
  s.authors                 = 'Google, Inc.'

  s.source                  = {
    :git => 'https://github.com/Firebase/firebase-ios-sdk.git',
    :tag => 'CocoaPods-' + s.version.to_s
  }

  s.swift_version           = '5.0'
  s.ios.deployment_target   = '10.0'
  s.osx.deployment_target   = '10.12'
  s.tvos.deployment_target  = '10.0'

  s.cocoapods_version       = '>= 1.4.0'
  s.prefix_header_file      = false

  s.requires_arc            = true
  s.source_files = [
    'FirebaseSegmentationFirestore/Sources/*.swift',
  ]

  s.dependency 'FirebaseFirestore', '~> 7.0'
  s.dependency 'FirebaseFirestoreSwift', '~> 7.0-beta'
  s.dependency 'FirebaseInstallations', '~> 7.0'
end
