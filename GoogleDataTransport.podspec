Pod::Spec.new do |s|
  s.name             = 'GoogleDataTransport'
  s.version          = '8.1.0'
  s.summary          = 'Google iOS SDK data transport.'

  s.description      = <<-DESC
Shared library for iOS SDK data transport needs.
                       DESC

  s.homepage         = 'https://developers.google.com/'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'
  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'DataTransport-' + s.version.to_s
  }

  ios_deployment_target = '9.0'
  osx_deployment_target = '10.12'
  tvos_deployment_target = '10.0'
  watchos_deployment_target = '6.0'

  s.ios.deployment_target = ios_deployment_target
  s.osx.deployment_target = osx_deployment_target
  s.tvos.deployment_target = tvos_deployment_target
  s.watchos.deployment_target = watchos_deployment_target

  # To develop or run the tests, >= 1.8.0 must be installed.
  s.cocoapods_version = '>= 1.4.0'

  s.prefix_header_file = false

  s.source_files = ['GoogleDataTransport/GDTCORLibrary/**/*',
                    'GoogleDataTransport/GDTCCTLibrary/**/*']
  s.public_header_files = 'GoogleDataTransport/GDTCORLibrary/Public/GoogleDataTransport/*.h'
  s.ios.frameworks = 'SystemConfiguration', 'CoreTelephony'
  s.osx.frameworks = 'SystemConfiguration', 'CoreTelephony'
  s.tvos.frameworks = 'SystemConfiguration'

  s.libraries = ['z']

  s.dependency 'nanopb', '~> 2.30906.0'

  header_search_paths = {
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}/"'
  }

  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'CLANG_UNDEFINED_BEHAVIOR_SANITIZER_NULLABILITY' => 'YES',
    'GCC_PREPROCESSOR_DEFINITIONS' =>
      # The nanopb pod sets these defs, so we must too. (We *do* require 16bit
      # (or larger) fields, so we'd have to set at least PB_FIELD_16BIT
      # anyways.)
      'PB_FIELD_32BIT=1 PB_NO_PACKED_STRUCTS=1 PB_ENABLE_MALLOC=1 GDTCOR_VERSION=' + s.version.to_s,
  }.merge(header_search_paths)

  common_test_sources = ['GoogleDataTransport/GDTCORTests/Common/**/*.{h,m}']

  # Test app specs
  if ENV['GDT_DEV'] && ENV['GDT_DEV'] == '1' then
    s.app_spec 'TestApp' do |app_spec|
      app_spec.platforms =  {:ios => ios_deployment_target, :osx => osx_deployment_target, :tvos => tvos_deployment_target}
      app_spec.source_files = [
        'GoogleDataTransport/GDTTestApp/*.swift',
        'GoogleDataTransport/GDTCORLibrary/Internal/GDTCORRegistrar.h',
        'GoogleDataTransport/GDTCORLibrary/Internal/GDTCORUploader.h',
        'GoogleDataTransport/GDTCORTests/Common/Categories/GDTCORFlatFileStorage+Testing.h',
        'GoogleDataTransport/GDTCORTests/Unit/Helpers/*.[hm]',
        'GoogleDataTransport/GDTTestApp/Bridging-Header.h',
      ]

      app_spec.ios.resources = ['GoogleDataTransport/GDTTestApp/ios/*.storyboard']
      app_spec.macos.resources = ['GoogleDataTransport/GDTTestApp/macos/*.storyboard']
      app_spec.tvos.resources = ['GoogleDataTransport/GDTTestApp/tvos/*.storyboard']
      app_spec.info_plist = {
        'UILaunchStoryboardName' => 'Main',
        'UIMainStoryboardFile' => 'Main',
        'NSMainStoryboardFile' => 'Main'
      }

      app_spec.pod_target_xcconfig = {
        'SWIFT_OBJC_BRIDGING_HEADER' => '$(PODS_TARGET_SRCROOT)/GoogleDataTransport/GDTTestApp/Bridging-Header.h'
      }
    end
  end

  # Unit test specs
  s.test_spec 'Tests-Unit' do |test_spec|
    test_spec.platforms = {:ios => ios_deployment_target, :osx => osx_deployment_target, :tvos => tvos_deployment_target}
    test_spec.requires_app_host = false
    test_spec.source_files = ['GoogleDataTransport/GDTCORTests/Unit/**/*.{h,m}'] + common_test_sources
    test_spec.pod_target_xcconfig = header_search_paths
  end

  s.test_spec 'Tests-Lifecycle' do |test_spec|
    test_spec.platforms = {:ios => ios_deployment_target, :osx => osx_deployment_target, :tvos => tvos_deployment_target}
    test_spec.requires_app_host = false
    test_spec.source_files = ['GoogleDataTransport/GDTCORTests/Lifecycle/**/*.{h,m}'] + common_test_sources
    test_spec.pod_target_xcconfig = header_search_paths
  end

  # Integration test specs
  s.test_spec 'Tests-Integration' do |test_spec|
    test_spec.platforms = {:ios => ios_deployment_target, :osx => osx_deployment_target, :tvos => tvos_deployment_target}
    test_spec.requires_app_host = false
    test_spec.source_files = ['GoogleDataTransport/GDTCORTests/Integration/**/*.{h,m}'] + common_test_sources
    test_spec.pod_target_xcconfig = header_search_paths
    test_spec.dependency 'GCDWebServer'
  end

  # Monkey test specs TODO(mikehaney24): Uncomment when travis is running >= cocoapods-1.8.0
  if ENV['GDT_DEV'] && ENV['GDT_DEV'] == '1' then
    s.test_spec 'Tests-Monkey' do |test_spec|
      test_spec.platforms = {:ios => ios_deployment_target, :osx => osx_deployment_target, :tvos => tvos_deployment_target}
      test_spec.requires_app_host = true
      test_spec.app_host_name = 'GoogleDataTransport/TestApp'
      test_spec.dependency 'GoogleDataTransport/TestApp'
      test_spec.source_files = ['GoogleDataTransport/GDTCORTests/Monkey/**/*.{swift}']
      test_spec.info_plist = {
        'GDT_MONKEYTEST' => '1'
      }
    end
  end

  # CCT Tests follow
  if ENV['GDT_DEV'] && ENV['GDT_DEV'] == '1' then
    s.app_spec 'CCTTestApp' do |app_spec|
      app_spec.platforms = {:ios => ios_deployment_target, :osx => osx_deployment_target, :tvos => tvos_deployment_target}
      app_spec.source_files = 'GoogleDataTransport/GDTCCTTestApp/**/*.swift'
      app_spec.ios.resources = ['GoogleDataTransport/GDTCCTTestApp/ios/*.storyboard']
      app_spec.macos.resources = ['GoogleDataTransport/GDTCCTTestApp/macos/*.storyboard']
      app_spec.tvos.resources = ['GoogleDataTransport/GDTCCTTestApp/tvos/*.storyboard']
      app_spec.dependency 'SwiftProtobuf'
      app_spec.info_plist = {
        'UILaunchStoryboardName' => 'Main',
        'UIMainStoryboardFile' => 'Main',
        'NSMainStoryboardFile' => 'Main'
      }
    end
  end

  common_cct_test_sources = ['GoogleDataTransport/GDTCCTTests/Common/**/*.{h,m}']

  # Test specs
  s.test_spec 'CCT-Tests-Unit' do |test_spec|
    test_spec.platforms = {:ios => ios_deployment_target, :osx => osx_deployment_target, :tvos => tvos_deployment_target}
    test_spec.requires_app_host = false
    test_spec.source_files = ['GoogleDataTransport/GDTCCTTests/Unit/**/*.{h,m}'] + common_cct_test_sources + common_test_sources
    test_spec.resources = ['GoogleDataTransport/GDTCCTTests/Data/**/*']
    test_spec.pod_target_xcconfig = header_search_paths
    test_spec.dependency 'GCDWebServer'
  end

  s.test_spec 'CCT-Tests-Integration' do |test_spec|
    test_spec.platforms = {:ios => ios_deployment_target, :osx => osx_deployment_target, :tvos => tvos_deployment_target}
    test_spec.requires_app_host = false
    test_spec.source_files = ['GoogleDataTransport/GDTCCTTests/Integration/**/*.{h,m}'] + common_cct_test_sources
    test_spec.resources = ['GoogleDataTransport/GDTCCTTests/Data/**/*']
    test_spec.pod_target_xcconfig = header_search_paths
  end

  # Monkey test specs, only enabled for development.
  if ENV['GDT_DEV'] && ENV['GDT_DEV'] == '1' then
    s.test_spec 'CCT-Tests-Monkey' do |test_spec|
      test_spec.platforms = {:ios => ios_deployment_target, :osx => osx_deployment_target, :tvos => tvos_deployment_target}
      test_spec.requires_app_host = true
      test_spec.app_host_name = 'GoogleDataTransport/CCTTestApp'
      test_spec.dependency 'GoogleDataTransport/CCTTestApp'
      test_spec.source_files = ['GoogleDataTransport/GDTCCTTests/Monkey/**/*.{swift}'] + common_cct_test_sources
      test_spec.info_plist = {
        'GDT_MONKEYTEST' => '1'
      }
    end
  end
end
