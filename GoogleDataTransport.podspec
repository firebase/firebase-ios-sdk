Pod::Spec.new do |s|
  s.name             = 'GoogleDataTransport'
  s.version          = '0.1.0'
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

  s.cocoapods_version = '>= 1.6.0'

  s.static_framework = true
  s.prefix_header_file = false

  s.source_files = 'GoogleDataTransport/GoogleDataTransport/**/*'
  s.public_header_files = 'GoogleDataTransport/GoogleDataTransport/Classes/Public/*.h'
  s.private_header_files = 'GoogleDataTransport/GoogleDataTransport/Classes/Private/*.h'

  s.dependency 'GoogleUtilities/Logger'

  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'GCC_TREAT_WARNINGS_AS_ERRORS' => 'YES',
    'CLANG_UNDEFINED_BEHAVIOR_SANITIZER_NULLABILITY' => 'YES'
  }

  common_test_sources = ['GoogleDataTransport/Tests/Common/**/*.{h,m}']

  # Unit test specs
  s.test_spec 'Tests-Unit' do |test_spec|
    test_spec.requires_app_host = false
    test_spec.source_files = ['GoogleDataTransport/Tests/Unit/**/*.{h,m}'] + common_test_sources
  end

  # Integration test specs
  s.test_spec 'Tests-Integration' do |test_spec|
    test_spec.requires_app_host = false
    test_spec.source_files = ['GoogleDataTransport/Tests/Integration/**/*.{h,m}'] + common_test_sources
    test_spec.compiler_flags = '-DGDT_LOG_TRACE_ENABLED=1'
    test_spec.dependency 'GCDWebServer'
  end
end
