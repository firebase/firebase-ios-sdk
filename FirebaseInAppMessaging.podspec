Pod::Spec.new do |s|
  s.name             = 'FirebaseInAppMessaging'
  s.version          = '0.14.1-pre'
  s.summary          = 'Firebase In-App Messaging for iOS'

  s.description      = <<-DESC
FirebaseInAppMessaging is the headless component of Firebase In-App Messaging on iOS client side.
See more product details at https://firebase.google.com/products/in-app-messaging/ about Firebase In-App Messaging.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'InAppMessaging-' + s.version.to_s
  }
  s.social_media_url = 'https://twitter.com/Firebase'
  s.ios.deployment_target = '8.0'

  s.cocoapods_version = '>= 1.4.0'
  s.static_framework = true
  s.prefix_header_file = false

  base_dir = "Firebase/InAppMessaging/"
  s.source_files = base_dir + '**/*.[mh]'
  s.public_header_files = base_dir + 'Public/*.h'

  s.pod_target_xcconfig = { 'GCC_PREPROCESSOR_DEFINITIONS' =>
      '$(inherited) ' +
      'FIRInAppMessaging_LIB_VERSION=' + String(s.version)
  }

  s.dependency 'FirebaseCore', '~> 6.0'
  s.ios.dependency 'FirebaseAnalyticsInterop', '~> 1.2'
  s.dependency 'FirebaseInstanceID', '~> 4.0'
end
