Pod::Spec.new do |s|
  s.name             = 'FirebaseAppAttestation'
  s.version          = '0.1.0'
  s.summary          = 'Firebase App Attestation SDK.'

  s.description      = <<-DESC
  Firebase App Attestation SDK.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'Attestation-' + s.version.to_s
  }
  s.social_media_url = 'https://twitter.com/Firebase'

  s.ios.deployment_target = '11.0'
  s.osx.deployment_target = '10.15'
  s.tvos.deployment_target = '11.0'

  s.cocoapods_version = '>= 1.4.0'
  s.static_framework = true
  s.prefix_header_file = false

  base_dir = "FirebaseAppAttestation/Source/"
  s.framework = 'Security'

  s.dependency 'FirebaseAppAttestationInterop', '~> 0.1.0'
  s.dependency 'FirebaseCore', '~> 6.6'
  s.dependency 'PromisesObjC', '~> 1.2'

  preprocessor_definitions = 'FIRAppAttestation_LIB_VERSION=' + String(s.version)
  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'GCC_PREPROCESSOR_DEFINITIONS' => preprocessor_definitions
  }

  # TODO: Consider less generic name instead of "Core"
  s.subspec 'Core' do |cs|
    subspec_dir = base_dir + 'Library/Core/'
    cs.source_files = subspec_dir + '**/*.[mh]'
    cs.public_header_files = subspec_dir + 'Public/*.h'

    cs.framework = 'Security'
  end

  s.subspec 'DeviceCheckAttestationProvider' do |ds|
    subspec_dir = base_dir + 'Library/DeviceCheckAttestationProvider/'
    ds.source_files = subspec_dir + '**/*.[mh]'
    ds.public_header_files = subspec_dir + 'Private/*.h'
    s.private_header_files = subspec_dir + 'Private/*.h'

    ds.dependency 'FirebaseAppAttestation/Core'
  end

  s.test_spec 'unit' do |unit_tests|
    unit_tests.platforms = {:ios => '11.0', :osx => '10.11', :tvos => '11.0'}
    unit_tests.source_files = base_dir + 'Tests/Unit/**/*.[mh]',
                              base_dir + 'Tests/Utils/**/*.[mh]'
    # unit_tests.resources = base_dir + 'Tests/Fixture/**/*'
    unit_tests.requires_app_host = true
    # unit_tests.dependency 'OCMock'
  end

  s.test_spec 'swift-unit' do |swift_unit_tests|
    swift_unit_tests.platforms = {:ios => '11.0', :osx => '10.11', :tvos => '11.0'}
    swift_unit_tests.source_files = base_dir + 'Tests/Unit/Swift/**/*.swift',
                                    base_dir + 'Tests/Unit/Swift/**/*.h'
  end

end
