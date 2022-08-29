Pod::Spec.new do |s|
  s.name             = 'FirebaseMessaging'
  s.version          = '9.6.0'
  s.summary          = 'Firebase Messaging'

  s.description      = <<-DESC
Firebase Messaging is a service that allows you to send data from your server to your users'
iOS device, and also to receive messages from devices on the same connection. The service handles
all aspects of queueing of messages and delivery to the target application running on the target
device, and it is completely free.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache-2.0', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'CocoaPods-' + s.version.to_s
  }
  s.social_media_url = 'https://twitter.com/Firebase'

  ios_deployment_target = '10.0'
  osx_deployment_target = '10.12'
  tvos_deployment_target = '10.0'
  watchos_deployment_target = '6.0'

  s.swift_version = '5.3'

  s.ios.deployment_target = ios_deployment_target
  s.osx.deployment_target = osx_deployment_target
  s.tvos.deployment_target = tvos_deployment_target
  s.watchos.deployment_target = watchos_deployment_target

  s.cocoapods_version = '>= 1.4.0'
  s.prefix_header_file = false

  base_dir = "FirebaseMessaging/"
  s.source_files = [
    base_dir + 'Sources/**/*',
    base_dir + 'Sources/Protogen/nanopb/*.h',
    base_dir + 'Interop/*.h',
    'Interop/Analytics/Public/*.h',
    'FirebaseCore/Extension/*.h',
    'FirebaseInstallations/Source/Library/Private/*.h',
  ]
  s.public_header_files = base_dir + 'Sources/Public/FirebaseMessaging/*.h'
  s.library = 'sqlite3'
  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'GCC_PREPROCESSOR_DEFINITIONS' =>
      # for nanopb:
      'PB_FIELD_32BIT=1 PB_NO_PACKED_STRUCTS=1 PB_ENABLE_MALLOC=1',
    # Unit tests do library imports using repo-root relative paths.
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}"',
  }
  s.ios.framework = 'SystemConfiguration'
  s.tvos.framework = 'SystemConfiguration'
  s.osx.framework = 'SystemConfiguration'
  s.weak_framework = 'UserNotifications'
  s.dependency 'FirebaseInstallations', '~> 9.0'
  s.dependency 'FirebaseCore', '~> 9.0'
  s.dependency 'GoogleUtilities/AppDelegateSwizzler', '~> 7.7'
  s.dependency 'GoogleUtilities/Reachability', '~> 7.7'
  s.dependency 'GoogleUtilities/Environment', '~> 7.7'
  s.dependency 'GoogleUtilities/UserDefaults', '~> 7.7'
  s.dependency 'GoogleDataTransport', '>= 9.1.4', '< 10.0.0'
  s.dependency 'nanopb', '>= 2.30908.0', '< 2.30910.0'

  s.test_spec 'unit' do |unit_tests|
    unit_tests.scheme = { :code_coverage => true }
    unit_tests.platforms = {
      :ios => ios_deployment_target,
      :osx => osx_deployment_target,
      :tvos => tvos_deployment_target
    }
    unit_tests.source_files = [
      'FirebaseMessaging/Tests/UnitTests*/*.{m,h,swift}',
      'SharedTestUtilities/URLSession/*.[mh]',
    ]
    unit_tests.requires_app_host = true
    unit_tests.pod_target_xcconfig = {
     'CLANG_ENABLE_OBJC_WEAK' => 'YES'
    }
    unit_tests.dependency 'OCMock'
  end

  s.test_spec 'integration' do |int_tests|
    int_tests.scheme = { :code_coverage => true }
    int_tests.platforms = {
      :ios => ios_deployment_target,
      :osx => osx_deployment_target,
      :tvos => tvos_deployment_target
    }
    int_tests.source_files = 'FirebaseMessaging/Tests/IntegrationTests/*.swift'
    int_tests.requires_app_host = true
    int_tests.resources = 'FirebaseMessaging/Tests/IntegrationTests/Resources/GoogleService-Info.plist'
  end
end
