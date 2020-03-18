Pod::Spec.new do |s|
  s.name             = 'GoogleDataTransport'
  s.version          = '5.1.0'
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

  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.11'
  s.tvos.deployment_target = '10.0'
  s.watchos.deployment_target = '6.0'

  # To develop or run the tests, >= 1.8.0.beta.1 must be installed.
  s.cocoapods_version = '>= 1.4.0'

  s.static_framework = true
  s.prefix_header_file = false

  s.source_files = 'GoogleDataTransport/GDTCORLibrary/**/*'
  s.public_header_files = 'GoogleDataTransport/GDTCORLibrary/Public/*.h'
  s.private_header_files = 'GoogleDataTransport/GDTCORLibrary/Private/*.h'
  s.ios.frameworks = 'SystemConfiguration', 'CoreTelephony'
  s.osx.frameworks = 'SystemConfiguration', 'CoreTelephony'
  s.tvos.frameworks = 'SystemConfiguration'

  header_search_paths = {
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}/GoogleDataTransport/"'
  }

  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'GCC_TREAT_WARNINGS_AS_ERRORS' => 'YES',
    'CLANG_UNDEFINED_BEHAVIOR_SANITIZER_NULLABILITY' => 'YES',
    'GCC_PREPROCESSOR_DEFINITIONS' => 'GDTCOR_VERSION=' + s.version.to_s
  }.merge(header_search_paths)

  common_test_sources = ['GoogleDataTransport/GDTCORTests/Common/**/*.{h,m}']

  # Test app specs
  if ENV['GDT_DEV'] && ENV['GDT_DEV'] == '1' then
    s.app_spec 'TestApp' do |app_spec|
      app_spec.platforms = {:ios => '8.0', :osx => '10.11', :tvos => '10.0'}
      app_spec.source_files = 'GoogleDataTransport/GDTTestApp/*.swift'
      app_spec.ios.resources = ['GoogleDataTransport/GDTTestApp/ios/*.storyboard']
      app_spec.macos.resources = ['GoogleDataTransport/GDTTestApp/macos/*.storyboard']
      app_spec.tvos.resources = ['GoogleDataTransport/GDTTestApp/tvos/*.storyboard']
      app_spec.info_plist = {
        'UILaunchStoryboardName' => 'Main',
        'UIMainStoryboardFile' => 'Main',
        'NSMainStoryboardFile' => 'Main'
      }
    end
  end

  # Unit test specs
  s.test_spec 'Tests-Unit' do |test_spec|
    test_spec.platforms = {:ios => '8.0', :osx => '10.11', :tvos => '10.0'}
    test_spec.requires_app_host = false
    test_spec.source_files = ['GoogleDataTransport/GDTCORTests/Unit/**/*.{h,m}'] + common_test_sources
    test_spec.pod_target_xcconfig = header_search_paths
  end

  s.test_spec 'Tests-Lifecycle' do |test_spec|
    test_spec.platforms = {:ios => '8.0', :osx => '10.11', :tvos => '10.0'}
    test_spec.requires_app_host = false
    test_spec.source_files = ['GoogleDataTransport/GDTCORTests/Lifecycle/**/*.{h,m}'] + common_test_sources
    test_spec.pod_target_xcconfig = header_search_paths
  end

  # Integration test specs
  s.test_spec 'Tests-Integration' do |test_spec|
    test_spec.platforms = {:ios => '8.0', :osx => '10.11', :tvos => '10.0'}
    test_spec.requires_app_host = false
    test_spec.source_files = ['GoogleDataTransport/GDTCORTests/Integration/**/*.{h,m}'] + common_test_sources
    test_spec.pod_target_xcconfig = header_search_paths
    test_spec.dependency 'GCDWebServer'
  end

  # Monkey test specs TODO(mikehaney24): Uncomment when travis is running >= cocoapods-1.8.0
  if ENV['GDT_DEV'] && ENV['GDT_DEV'] == '1' then
    s.test_spec 'Tests-Monkey' do |test_spec|
      test_spec.platforms = {:ios => '8.0', :osx => '10.11', :tvos => '10.0'}
      test_spec.requires_app_host = true
      test_spec.app_host_name = 'GoogleDataTransport/TestApp'
      test_spec.dependency 'GoogleDataTransport/TestApp'
      test_spec.source_files = ['GoogleDataTransport/GDTCORTests/Monkey/**/*.{swift}']
      test_spec.info_plist = {
        'GDT_MONKEYTEST' => '1'
      }
    end
  end

end
