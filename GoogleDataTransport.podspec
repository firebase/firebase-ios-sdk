Pod::Spec.new do |s|
  s.name             = 'GoogleDataTransport'
  s.version          = '0.1.3'
  s.summary          = 'Google iOS SDK data transport.'

  s.description      = <<-DESC
Shared library for iOS SDK data transport needs.
                       DESC

  s.homepage         = 'https://developers.google.com/'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'
  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'GoogleDataTransport-' + s.version.to_s
  }

  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.11'
  s.tvos.deployment_target = '10.0'

  # To develop or run the tests, >= 1.6.0 must be installed.
  s.cocoapods_version = '>= 1.4.0'

  s.static_framework = true
  s.prefix_header_file = false

  s.source_files = 'GoogleDataTransport/GDTLibrary/**/*'
  s.public_header_files = 'GoogleDataTransport/GDTLibrary/Public/*.h'
  s.private_header_files = 'GoogleDataTransport/GDTLibrary/Private/*.h'

  header_search_paths = {
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}/GoogleDataTransport/"'
  }

  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'GCC_TREAT_WARNINGS_AS_ERRORS' => 'YES',
    'CLANG_UNDEFINED_BEHAVIOR_SANITIZER_NULLABILITY' => 'YES'
  }.merge(header_search_paths)

  common_test_sources = ['GoogleDataTransport/GDTTests/Common/**/*.{h,m}']

  # Unit test specs
  s.test_spec 'Tests-Unit' do |test_spec|
    test_spec.requires_app_host = false
    test_spec.source_files = ['GoogleDataTransport/GDTTests/Unit/**/*.{h,m}'] + common_test_sources
    test_spec.pod_target_xcconfig = header_search_paths
  end

  s.test_spec 'Tests-Lifecycle' do |test_spec|
    test_spec.requires_app_host = false
    test_spec.source_files = ['GoogleDataTransport/GDTTests/Lifecycle/**/*.{h,m}'] + common_test_sources
    test_spec.pod_target_xcconfig = header_search_paths
  end

  # Integration test specs
  s.test_spec 'Tests-Integration' do |test_spec|
    test_spec.requires_app_host = false
    test_spec.source_files = ['GoogleDataTransport/GDTTests/Integration/**/*.{h,m}'] + common_test_sources
    test_spec.pod_target_xcconfig = header_search_paths
    test_spec.dependency 'GCDWebServer'
  end
end
