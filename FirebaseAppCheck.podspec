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
  s.static_framework = true
  s.prefix_header_file = false

  base_dir = "FirebaseAppCheck/Source/"

  s.dependency 'FirebaseAppCheckInterop', '~> 7.0.0-beta'
  s.dependency 'FirebaseCore', '~> 7.0'
  s.dependency 'PromisesObjC', '~> 1.2'

  preprocessor_definitions = 'FIRAppCheck_LIB_VERSION=' + String(s.version)
  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'GCC_PREPROCESSOR_DEFINITIONS' => preprocessor_definitions,
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}"'
  }

  # TODO: Consider less generic name instead of "Core"
  s.subspec 'Core' do |cs|
    subspec_dir = base_dir + 'Library/Core/'
    cs.source_files = subspec_dir + '**/*.[mh]'
    cs.public_header_files = subspec_dir + 'Public/*.h'

    cs.dependency 'GoogleUtilities/Environment'
  end

  s.subspec 'DeviceCheckProvider' do |ds|
    subspec_dir = base_dir + 'Library/DeviceCheckProvider/'
    ds.source_files = subspec_dir + '**/*.[mh]'
    ds.public_header_files = subspec_dir + 'Private/*.h'
    ds.private_header_files = subspec_dir + 'Private/*.h'

    ds.framework = 'DeviceCheck'
    ds.dependency 'FirebaseAppCheck/Core'
  end

  s.test_spec 'unit' do |unit_tests|
    unit_tests.platforms = {:ios => '11.0', :osx => '10.11', :tvos => '11.0'}
    unit_tests.source_files = base_dir + 'Tests/Unit/**/*.[mh]',
                              base_dir + 'Tests/Utils/**/*.[mh]',
                              'SharedTestUtilities/**/*'
    unit_tests.resources = base_dir + 'Tests/Fixture/**/*'
    unit_tests.requires_app_host = true
    unit_tests.dependency 'OCMock'
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
