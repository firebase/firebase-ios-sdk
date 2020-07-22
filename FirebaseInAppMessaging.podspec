Pod::Spec.new do |s|
  s.name             = 'FirebaseInAppMessaging'
  s.version          = '0.23.0'
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
  s.ios.deployment_target = '9.0'

  s.cocoapods_version = '>= 1.4.0'
  s.static_framework = true
  s.prefix_header_file = false

  base_dir = "FirebaseInAppMessaging/"
  s.source_files = [
    base_dir + "Sources/**/*.[cmh]",
    'Interop/Analytics/Public/*.h',
    'FirebaseABTesting/Sources/Private/*.h',
    'FirebaseCore/Sources/Private/*.h',
    'FirebaseInstallations/Source/Library/Private/*.h',
    'GoogleUtilities/Environment/Private/*.h',
  ]
  s.public_header_files = base_dir + 'Sources/Public/*.h'
  s.private_header_files = base_dir + 'Sources/Private/**/*.h'

  s.resource_bundles = {
    'InAppMessagingDisplayResources' => [ base_dir + 'Resources/*.xib',
                                   base_dir + 'Resources/*.storyboard',
                                   base_dir + 'Resources/*.png']
  }

  s.pod_target_xcconfig = {
    'GCC_PREPROCESSOR_DEFINITIONS' =>
			'GPB_USE_PROTOBUF_FRAMEWORK_IMPORTS=1 ' +
      '$(inherited) ' +
      'FIRInAppMessaging_LIB_VERSION=' + String(s.version) + ' ' +
      'PB_FIELD_32BIT=1 PB_NO_PACKED_STRUCTS=1 PB_ENABLE_MALLOC=1',
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}"'
  }

  s.dependency 'FirebaseCore', '~> 6.8'
  s.dependency 'FirebaseInstallations', '~> 1.1'
  s.dependency 'FirebaseABTesting', '~> 4.1'
  s.dependency 'GoogleUtilities/Environment', '~> 6.7'
  s.dependency 'nanopb', '~> 1.30905.0'

  s.test_spec 'unit' do |unit_tests|
      unit_tests.source_files = 'FirebaseInAppMessaging/Tests/Unit/*.[mh]'
      unit_tests.resources = 'FirebaseInAppMessaging/Tests/Unit/*.txt'
      unit_tests.requires_app_host = true
      unit_tests.dependency 'OCMock'
   end

end
