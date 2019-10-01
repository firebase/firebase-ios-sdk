Pod::Spec.new do |s|
  s.name             = 'FirebaseInAppMessagingDisplay'
  s.version          = '0.15.6-pre'
  s.summary          = 'Firebase In-App Messaging UI for iOS'

  s.description      = <<-DESC
FirebaseInAppMessagingDisplay is the default client UI implementation for
Firebase In-App Messaging SDK.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'InAppMessagingDisplay-' + s.version.to_s
  }
  s.social_media_url = 'https://twitter.com/Firebase'
  s.ios.deployment_target = '8.0'

  s.cocoapods_version = '>= 1.4.0'
  s.static_framework = true
  s.prefix_header_file = false

  base_dir = "Firebase/InAppMessagingDisplay/"
  s.source_files = base_dir + '**/*.[mh]'
  s.public_header_files = base_dir + 'Public/*.h'

  s.resource_bundles = {
    'InAppMessagingDisplayResources' => [ base_dir + 'Resources/*.xib',
                                   base_dir + 'Resources/*.storyboard',
                                   base_dir + 'Resources/*.png']
  }

  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'GCC_PREPROCESSOR_DEFINITIONS' =>
      '$(inherited) ' +
      'FIRInAppMessagingDisplay_LIB_VERSION=' + String(s.version)
  }

  s.dependency 'FirebaseCore', '~> 6.2'
  s.dependency 'FirebaseInAppMessaging', '>=0.15.0'
end
