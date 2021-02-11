Pod::Spec.new do |s|
  s.name                    = 'FirebaseInAppMessagingSwift'
  s.version                 = '7.7.0-beta'
  s.summary                 = 'Swift Extensions for in-app messaging'

  s.description      = <<-DESC
FirebaseInAppMessaging is the headless component of Firebase In-App Messaging on iOS client side.
See more product details at https://firebase.google.com/products/in-app-messaging/ about Firebase In-App Messaging.
                       DESC

  s.homepage                = 'https://developers.google.com/'
  s.license                 = { :type => 'Apache', :file => 'LICENSE' }
  s.authors                 = 'Google, Inc.'

  s.source                  = {
    :git => 'https://github.com/Firebase/firebase-ios-sdk.git',
    :tag => 'CocoaPods-' + s.version.to_s
  }

  s.swift_version           = '5.3'
  s.ios.deployment_target   = '13.0'

  s.cocoapods_version       = '>= 1.4.0'
  s.static_framework        = true
  s.prefix_header_file      = false

  s.requires_arc            = true
  s.source_files = [
    'FirebaseInAppMessaging/Swift/Source/**/*.swift',
  ]

  s.dependency 'FirebaseInAppMessaging'
end
