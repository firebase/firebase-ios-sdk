Pod::Spec.new do |s|
  s.name             = 'FirebaseAppCheck'
  s.version          = '11.7.0'
  s.summary          = 'Firebase App Check SDK.'

  s.description      = <<-DESC
  Firebase SDK for anti-abuse compatibility.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache-2.0', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'CocoaPods-' + s.version.to_s
  }
  s.social_media_url = 'https://twitter.com/Firebase'

  ios_deployment_target = '13.0'
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

  base_dir = "FirebaseAppCheck/"

  s.source_files = [
    base_dir + 'Sources/**/*.[mh]',
    'FirebaseCore/Extension/*.h',
  ]
  s.public_header_files = base_dir + 'Sources/Public/FirebaseAppCheck/*.h'

  s.ios.weak_framework = 'DeviceCheck'
  s.osx.weak_framework = 'DeviceCheck'
  s.tvos.weak_framework = 'DeviceCheck'

  s.dependency 'AppCheckCore', '~> 11.0'
  s.dependency 'FirebaseAppCheckInterop', '~> 11.0'
  s.dependency 'FirebaseCore', '~> 11.7.0'
  s.dependency 'GoogleUtilities/Environment', '~> 8.0'
  s.dependency 'GoogleUtilities/UserDefaults', '~> 8.0'

  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}"'
  }

  s.test_spec 'unit' do |unit_tests|
    unit_tests.platforms = {
      :ios => ios_deployment_target,
      :osx => osx_deployment_target,
      :tvos => tvos_deployment_target
    }
    unit_tests.source_files = [
      base_dir + 'Tests/Unit/**/*.[mh]',
      'SharedTestUtilities/AppCheckFake/*',
      'SharedTestUtilities/AppCheckBackoffWrapperFake/*',
      'SharedTestUtilities/Date/*',
      'SharedTestUtilities/URLSession/*',
    ]

    unit_tests.resources = base_dir + 'Tests/Unit/Fixture/**/*'
    unit_tests.dependency 'OCMock'
    unit_tests.requires_app_host = true
  end

  s.test_spec 'integration' do |integration_tests|
    integration_tests.platforms = {
      :ios => ios_deployment_target,
      :osx => osx_deployment_target,
      :tvos => tvos_deployment_target
    }
    integration_tests.source_files = [
      base_dir + 'Tests/Integration/**/*.swift',
    ]
    integration_tests.requires_app_host = true
  end

  s.test_spec 'swift-unit' do |swift_unit_tests|
    swift_unit_tests.platforms = {
      :ios => ios_deployment_target,
      :osx => osx_deployment_target,
      :tvos => tvos_deployment_target
    }
    swift_unit_tests.source_files = [
      base_dir + 'Tests/Unit/Swift/**/*.swift',
    ]
  end

end
