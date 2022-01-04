#
# Be sure to run `pod lib lint FirebaseRemoteConfigSwift.podspec' to ensure this is a
# valid spec before submitting.
#

Pod::Spec.new do |s|
  s.name                    = 'FirebaseRemoteConfigSwift'
  s.version                 = '8.10.0-beta'
  s.summary                 = 'Swift Extensions for Google Cloud RemoteConfig'

  s.description      = <<-DESC
  Firebase Remote Config is a cloud service that lets you change the
  appearance and behavior of your app without requiring users to download an
  app update.
                       DESC

  s.homepage                = 'https://developers.google.com/'
  s.license                 = { :type => 'Apache', :file => 'LICENSE' }
  s.authors                 = 'Google, Inc.'

  s.source                  = {
    :git => 'https://github.com/Firebase/firebase-ios-sdk.git',
    :tag => 'CocoaPods-' + s.version.to_s
  }
  s.social_media_url = 'https://twitter.com/Firebase'

  s.swift_version           = '5.3'

  s.ios.deployment_target = '10.0'
  s.osx.deployment_target = '10.12'
  s.tvos.deployment_target = '10.0'
  s.watchos.deployment_target = '6.0'

  s.cocoapods_version       = '>= 1.4.0'
  s.prefix_header_file      = false

  s.requires_arc            = true
  s.source_files = [
    'FirebaseRemoteConfigSwift/Sources/**/*.swift',
  ]

  s.dependency 'FirebaseRemoteConfig', '~> 8.0'
end
