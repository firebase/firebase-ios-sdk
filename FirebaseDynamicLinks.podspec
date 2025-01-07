Pod::Spec.new do |s|
  s.name             = 'FirebaseDynamicLinks'
  s.version          = '11.7.0'
  s.summary          = 'Firebase Dynamic Links'

  s.description      = <<-DESC
Firebase Dynamic Links are deep links that enhance user experience and increase engagement by retaining context post-install, across platforms.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache-2.0', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'CocoaPods-' + s.version.to_s
  }
  s.social_media_url = 'https://twitter.com/Firebase'
  s.ios.deployment_target = '13.0'

  s.swift_version = '5.9'

  s.cocoapods_version = '>= 1.12.0'
  s.prefix_header_file = false

  s.source_files = [
    'FirebaseDynamicLinks/Sources/**/*.[mh]',
    'Interop/Analytics/Public/*.h',
    'FirebaseCore/Extension/*.h',
  ]
  s.public_header_files = 'FirebaseDynamicLinks/Sources/Public/FirebaseDynamicLinks/*.h'
  s.resource_bundles = {
    "#{s.module_name}_Privacy" => 'FirebaseDynamicLinks/Sources/Resources/PrivacyInfo.xcprivacy'
  }
  s.frameworks = 'QuartzCore'
  s.weak_framework = 'WebKit'
  s.dependency 'FirebaseCore', '~> 11.7.0'

  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'GCC_PREPROCESSOR_DEFINITIONS' => 'FIRDynamicLinks3P GIN_SCION_LOGGING',
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}"'
  }

  s.test_spec 'unit' do |unit_tests|
    unit_tests.scheme = { :code_coverage => true }
    unit_tests.source_files = [
      'FirebaseDynamicLinks/Tests/Unit/*.[mh]',
    ]
    unit_tests.requires_app_host = true
    unit_tests.resources = 'FirebaseDynamicLinks/Tests/Unit/GoogleService-Info.plist',
                           # Supply plist for custom domain testing.
                           'FirebaseDynamicLinks/Tests/Unit/DL-Info.plist'
    unit_tests.dependency 'OCMock'
    unit_tests.dependency 'GoogleUtilities/MethodSwizzler', '~> 8.0'
    unit_tests.dependency 'GoogleUtilities/SwizzlerTestHelpers', '~> 8.0'
  end
end
