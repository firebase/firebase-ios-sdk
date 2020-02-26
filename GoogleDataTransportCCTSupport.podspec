
Pod::Spec.new do |s|
  s.name             = 'GoogleDataTransportCCTSupport'
  s.version          = '1.4.1'
  s.summary          = 'Support library for the GoogleDataTransport CCT backend target.'


  s.description      = <<-DESC
Support library to provide event prioritization and uploading for the GoogleDataTransport CCT backend target.
                       DESC

  s.homepage         = 'https://developers.google.com/'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'
  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'DataTransportCCTSupport-' + s.version.to_s
  }

  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.11'
  s.tvos.deployment_target = '10.0'
  s.watchos.deployment_target = '6.0'

  # To develop or run the tests, >= 1.8.0.beta.1 must be installed.
  s.cocoapods_version = '>= 1.4.0'

  s.static_framework = true
  s.prefix_header_file = false

  s.source_files = 'GoogleDataTransportCCTSupport/GDTCCTLibrary/**/*'
  s.private_header_files = 'GoogleDataTransportCCTSupport/GDTCCTLibrary/Private/*.h'

  s.libraries = ['z']

  s.dependency 'GoogleDataTransport', '~> 4.0'
  s.dependency 'nanopb', '~> 0.3.901'

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
      'PB_FIELD_32BIT=1 PB_NO_PACKED_STRUCTS=1 PB_ENABLE_MALLOC=1 GDTCCTSUPPORT_VERSION=' + s.version.to_s,
  }.merge(header_search_paths)

  # Test app specs
  if ENV['GDT_DEV'] && ENV['GDT_DEV'] == '1' then
    s.app_spec 'TestApp' do |app_spec|
      app_spec.platforms = {:ios => '8.0', :osx => '10.11', :tvos => '10.0'}
      app_spec.source_files = 'GoogleDataTransportCCTSupport/GDTCCTTestApp/**/*.swift'
      app_spec.ios.resources = ['GoogleDataTransportCCTSupport/GDTCCTTestApp/ios/*.storyboard']
      app_spec.macos.resources = ['GoogleDataTransportCCTSupport/GDTCCTTestApp/macos/*.storyboard']
      app_spec.tvos.resources = ['GoogleDataTransportCCTSupport/GDTCCTTestApp/tvos/*.storyboard']
      app_spec.dependency 'SwiftProtobuf'
      app_spec.info_plist = {
        'UILaunchStoryboardName' => 'Main',
        'UIMainStoryboardFile' => 'Main',
        'NSMainStoryboardFile' => 'Main'
      }
    end
  end

  # Test specs
  s.test_spec 'Tests-Unit' do |test_spec|
    test_spec.platforms = {:ios => '8.0', :osx => '10.11', :tvos => '10.0'}
    test_spec.requires_app_host = false
    test_spec.source_files = 'GoogleDataTransportCCTSupport/GDTCCTTests/Unit/**/*.{h,m}'
    test_spec.resources = ['GoogleDataTransportCCTSupport/GDTCCTTests/Data/**/*']
    test_spec.pod_target_xcconfig = header_search_paths
    test_spec.dependency 'GCDWebServer'
  end

  s.test_spec 'Tests-Integration' do |test_spec|
    test_spec.platforms = {:ios => '8.0', :osx => '10.11', :tvos => '10.0'}
    test_spec.requires_app_host = false
    test_spec.source_files = 'GoogleDataTransportCCTSupport/GDTCCTTests/Integration/**/*.{h,m}'
    test_spec.resources = ['GoogleDataTransportCCTSupport/GDTCCTTests/Data/**/*']
    test_spec.pod_target_xcconfig = header_search_paths
  end

  # Monkey test specs, only enabled for development.
  if ENV['GDT_DEV'] && ENV['GDT_DEV'] == '1' then
    s.test_spec 'Tests-Monkey' do |test_spec|
      test_spec.platforms = {:ios => '8.0', :osx => '10.11', :tvos => '10.0'}
      test_spec.requires_app_host = true
      test_spec.app_host_name = 'GoogleDataTransportCCTSupport/TestApp'
      test_spec.dependency 'GoogleDataTransportCCTSupport/TestApp'
      test_spec.source_files = ['GoogleDataTransportCCTSupport/GDTCCTTests/Monkey/**/*.{swift}']
      test_spec.info_plist = {
        'GDT_MONKEYTEST' => '1'
      }
    end
  end

end
