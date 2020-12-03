Pod::Spec.new do |s|
  s.name             = 'FirebaseAppCheck'
  s.version          = '7.0.0-beta'
  s.summary          = 'Firebase App Check SDK.'

  s.description      = <<-DESC
  Firebase App Check SDK.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'AppCheck-' + s.version.to_s
  }
  s.social_media_url = 'https://twitter.com/Firebase'

  s.ios.deployment_target = '11.0'
  s.osx.deployment_target = '10.15'
  s.tvos.deployment_target = '11.0'

  s.cocoapods_version = '>= 1.4.0'
  s.prefix_header_file = false

  base_dir = "FirebaseAppCheck/"

  s.source_files = [
    base_dir + 'Sources/**/*.[mh]',
    'FirebaseCore/Sources/Private/*.h',
  ]
  s.public_header_files = base_dir + 'Sources/Public/FirebaseAppCheck/*.h'

  s.framework = 'DeviceCheck'

  s.dependency 'FirebaseCore', '~> 7.0'
  s.dependency 'PromisesObjC', '~> 1.2'
  s.dependency 'GoogleUtilities/Environment', '~> 7.0'

  preprocessor_definitions = 'FIRAppCheck_LIB_VERSION=' + String(s.version)
  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'GCC_PREPROCESSOR_DEFINITIONS' => preprocessor_definitions,
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}"'
  }

  s.test_spec 'unit' do |unit_tests|
    unit_tests.platforms = {:ios => '11.0', :osx => '10.11', :tvos => '11.0'}
    unit_tests.source_files = [
      base_dir + 'Tests/Unit/**/*.[mh]',
      base_dir + 'Tests/Utils/**/*.[mh]',
      'SharedTestUtilities/AppCheckFake/*',
      'SharedTestUtilities/Date/*',
      'SharedTestUtilities/URLSession/*',
    ]

    unit_tests.resources = base_dir + 'Tests/Fixture/**/*'
    unit_tests.dependency 'OCMock'
    unit_tests.requires_app_host = true
  end

  s.test_spec 'integration' do |integration_tests|
    integration_tests.platforms = {:ios => '11.0', :osx => '10.11', :tvos => '11.0'}
    integration_tests.source_files = base_dir + 'Tests/Integration/**/*.[mh]',
                              base_dir + 'Tests/Integration/**/*.[mh]',
                              integration_tests.resources = base_dir + 'Tests/Fixture/**/*'
                              integration_tests.requires_app_host = true
  end

  s.test_spec 'swift-unit' do |swift_unit_tests|
    swift_unit_tests.platforms = {:ios => '11.0', :osx => '10.11', :tvos => '11.0'}
    swift_unit_tests.source_files = base_dir + 'Tests/Unit/Swift/**/*.swift',
                                    base_dir + 'Tests/Unit/Swift/**/*.h'
  end

end
