Pod::Spec.new do |s|
  s.name             = 'FirebaseInAppMessaging'
  s.version          = '8.7.0-beta'
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
    :tag => 'CocoaPods-' + s.version.to_s
  }
  s.social_media_url = 'https://twitter.com/Firebase'
  s.ios.deployment_target = '10.0'
  s.tvos.deployment_target = '10.0'

  s.cocoapods_version = '>= 1.4.0'
  s.prefix_header_file = false

  base_dir = "FirebaseInAppMessaging/"
  s.ios.source_files = [
    base_dir + "Sources/*.[cmh]",
	base_dir + "Sources/Analytics/**/*.[cmh]",
	base_dir + "Sources/Data/**/*.[cmh]",
	base_dir + "Sources/DefaultUI/**/*.[cmh]",
	base_dir + "Sources/DisplayTrigger/**/*.[cmh]",
	base_dir + "Sources/Flows/**/*.[cmh]",
	base_dir + "Sources/Private/**/*.[cmh]",
	base_dir + "Sources/Public/**/*.[cmh]",
	base_dir + "Sources/RenderingObjects/**/*.[cmh]",
	base_dir + "Sources/Runtime/**/*.[cmh]",
	base_dir + "Sources/Util/**/*.[cmh]",
    'Interop/Analytics/Public/*.h',
    'FirebaseABTesting/Sources/Private/*.h',
    'FirebaseCore/Sources/Private/*.h',
    'FirebaseInstallations/Source/Library/Private/*.h',
  ]

  s.tvos.source_files = [
    base_dir + "Sources/*.[cmh]",
	base_dir + "Sources/Analytics/**/*.[cmh]",
	base_dir + "Sources/Data/**/*.[cmh]",
	base_dir + "Sources/DisplayTrigger/**/*.[cmh]",
	base_dir + "Sources/Flows/**/*.[cmh]",
	base_dir + "Sources/Private/**/*.[cmh]",
	base_dir + "Sources/Public/**/*.[cmh]",
	base_dir + "Sources/RenderingObjects/**/*.[cmh]",
	base_dir + "Sources/Runtime/**/*.[cmh]",
	base_dir + "Sources/Util/**/*.[cmh]",
    'Interop/Analytics/Public/*.h',
    'FirebaseABTesting/Sources/Private/*.h',
    'FirebaseCore/Sources/Private/*.h',
    'FirebaseInstallations/Source/Library/Private/*.h',
  ]

  s.public_header_files = base_dir + 'Sources/Public/FirebaseInAppMessaging/*.h'

  s.ios.resource_bundles = {
    'InAppMessagingDisplayResources' => [
       base_dir + 'iOS/Resources/*.{storyboard,png}',
     ]
  }

  s.pod_target_xcconfig = {
    'GCC_PREPROCESSOR_DEFINITIONS' =>
      '$(inherited) ' +
      'PB_FIELD_32BIT=1 PB_NO_PACKED_STRUCTS=1 PB_ENABLE_MALLOC=1',
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}"'
  }

  s.framework = 'UIKit'

  s.dependency 'FirebaseCore', '~> 8.0'
  s.dependency 'FirebaseInstallations', '~> 8.0'
  s.dependency 'FirebaseABTesting', '~> 8.0'
  s.dependency 'GoogleUtilities/Environment', '~> 7.4'
  s.dependency 'nanopb', '~> 2.30908.0'

  s.test_spec 'unit' do |unit_tests|
      unit_tests.scheme = { :code_coverage => true }
      unit_tests.source_files = 'FirebaseInAppMessaging/Tests/Unit/*.[mh]'
      unit_tests.resources = 'FirebaseInAppMessaging/Tests/Unit/*.txt'
      unit_tests.requires_app_host = true
      unit_tests.dependency 'OCMock'
   end
end
