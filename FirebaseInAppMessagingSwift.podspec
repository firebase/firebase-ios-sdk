Pod::Spec.new do |s|
  s.name                    = 'FirebaseInAppMessagingSwift'
  s.version                 = '8.10.0-beta'
  s.summary                 = 'Swift Extensions for Firebase In-App Messaging'

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
  s.prefix_header_file      = false

  s.source_files = [
    'FirebaseInAppMessaging/Swift/Source/**/*.swift',
  ]

  s.test_spec 'unit' do |unit_tests|
      unit_tests.scheme = { :code_coverage => true }
      unit_tests.source_files = 'FirebaseInAppMessaging/Swift/Tests/Unit/*.swift'
      unit_tests.requires_app_host = true
   end

  s.framework = 'UIKit'

  s.dependency 'FirebaseInAppMessaging', '~> 8.0-beta'
end
