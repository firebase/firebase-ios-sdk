
Pod::Spec.new do |s|
  s.name             = 'GoogleDataTransportCCTSupport'
  s.version          = '0.1.2'
  s.summary          = 'Support library for the GoogleDataTransport CCT backend target.'


  s.description      = <<-DESC
Support library to provide event prioritization and uploading for the GoogleDataTransport CCT backend target.
                       DESC

  s.homepage         = 'https://developers.google.com/'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'
  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'GoogleDataTransportCCTSupport-' + s.version.to_s
  }

  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.11'
  s.tvos.deployment_target = '10.0'

  # To develop or run the tests, >= 1.6.0 must be installed.
  s.cocoapods_version = '>= 1.4.0'

  s.static_framework = true
  s.prefix_header_file = false

  s.source_files = 'GoogleDataTransportCCTSupport/GDTCCTLibrary/**/*'
  s.private_header_files = 'GoogleDataTransportCCTSupport/GDTCCTLibrary/Private/*.h'

  s.dependency 'GoogleDataTransport', '~> 0.1.1'
  s.dependency 'nanopb'

  header_search_paths = {
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}/GoogleDataTransportCCTSupport/"'
  }

  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'GCC_TREAT_WARNINGS_AS_ERRORS' => 'YES',
    'CLANG_UNDEFINED_BEHAVIOR_SANITIZER_NULLABILITY' => 'YES',
    'GCC_PREPROCESSOR_DEFINITIONS' =>
      # The nanopb pod sets these defs, so we must too. (We *do* require 16bit
      # (or larger) fields, so we'd have to set at least PB_FIELD_16BIT
      # anyways.)
      'PB_FIELD_32BIT=1 PB_NO_PACKED_STRUCTS=1 PB_ENABLE_MALLOC=1',
  }.merge(header_search_paths)

  # Test specs
  s.test_spec 'Tests-Unit' do |test_spec|
    test_spec.requires_app_host = false
    test_spec.source_files = 'GoogleDataTransportCCTSupport/GDTCCTTests/Unit/**/*.{h,m}'
    test_spec.resources = ['GoogleDataTransportCCTSupport/GDTCCTTests/Data/**/*']
    test_spec.pod_target_xcconfig = header_search_paths
    test_spec.dependency 'GCDWebServer'
  end

  s.test_spec 'Tests-Integration' do |test_spec|
    test_spec.requires_app_host = false
    test_spec.source_files = 'GoogleDataTransportCCTSupport/GDTCCTTests/Integration/**/*.{h,m}'
    test_spec.resources = ['GoogleDataTransportCCTSupport/GDTCCTTests/Data/**/*']
    test_spec.pod_target_xcconfig = header_search_paths
  end

end
