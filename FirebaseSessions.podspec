Pod::Spec.new do |s|
  s.name             = 'FirebaseSessions'
  s.version          = '11.5.0'
  s.summary          = 'Firebase Sessions'

  s.description      = <<-DESC
  Not for public use.
  SDK for sending events for Firebase App Quality Sessions.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache-2.0', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'CocoaPods-' + s.version.to_s
  }
  s.social_media_url = 'https://twitter.com/Firebase'

  ios_deployment_target = '12.0'
  osx_deployment_target = '10.15'
  tvos_deployment_target = '13.0'
  watchos_deployment_target = '7.0'

  s.swift_version = '5.9'

  s.ios.deployment_target = ios_deployment_target
  s.osx.deployment_target = osx_deployment_target
  s.tvos.deployment_target = tvos_deployment_target
  s.watchos.deployment_target = watchos_deployment_target

  s.cocoapods_version = '>= 1.12.0'
  s.prefix_header_file = false

  base_dir = "FirebaseSessions/"
  s.source_files = [
    base_dir + 'Sources/**/*.{swift}',
    base_dir + 'SourcesObjC/**/*.{c,h,m,mm}',
  ]

  s.dependency 'FirebaseCore', '11.5'
  s.dependency 'FirebaseCoreExtension', '11.5'
  s.dependency 'FirebaseInstallations', '~> 11.0'
  s.dependency 'GoogleDataTransport', '~> 10.0'
  s.dependency 'GoogleUtilities/Environment', '~> 8.0'
  s.dependency 'GoogleUtilities/UserDefaults', '~> 8.0'
  s.dependency 'nanopb', '~> 3.30910.0'
  s.dependency 'PromisesSwift', '~> 2.1'

  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}"',
    'GCC_PREPROCESSOR_DEFINITIONS' =>
      # For nanopb:
      'PB_FIELD_32BIT=1 PB_NO_PACKED_STRUCTS=1 PB_ENABLE_MALLOC=1',
  }

  s.test_spec 'unit' do |unit_tests|
    unit_tests.scheme = { :code_coverage => true }
    unit_tests.platforms = {
      :ios => ios_deployment_target,
      :osx => osx_deployment_target,
      :tvos => tvos_deployment_target,
      # https://github.com/CocoaPods/CocoaPods/issues/8283
      # :watchos => watchos_deployment_target,
    }
    unit_tests.source_files = base_dir + 'Tests/Unit/**/*.swift'
    unit_tests.resources = base_dir + 'Tests/Fixtures/**/*'
    unit_tests.requires_app_host = true
  end
end
