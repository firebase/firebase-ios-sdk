Pod::Spec.new do |s|
  s.name             = 'FirebaseCoreDiagnostics'
  s.version          = '1.5.0'
  s.summary          = 'Firebase Core Diagnostics'

  s.description      = <<-DESC
Firebase Core Diagnostics collects diagnostic data to help improve and provide Firebase services.
This SDK is integrated using a 'soft-link' mechanism and the bits be omitted by using a
non-Cocoapod integration. This library also respects the Firebase global data collection flag.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'CoreDiagnostics-' + s.version.to_s
  }
  s.social_media_url = 'https://twitter.com/Firebase'
  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.11'
  s.tvos.deployment_target = '10.0'
  s.watchos.deployment_target = '6.0'

  s.cocoapods_version = '>= 1.4.0'
  s.static_framework = true
  s.prefix_header_file = false

  header_search_paths = {
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}" ' +
                             '"${PODS_TARGET_SRCROOT}/Firebase/CoreDiagnostics/"'
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

  s.source_files = [
    'Firebase/CoreDiagnostics/FIRCDLibrary/**/*.[cmh]',
    'GoogleDataTransport/GDTCORLibrary/Internal/*.h',
    'GoogleUtilities/Environment/Private/*.h',
    'GoogleUtilities/Logger/Private/*.h',
    'Interop/CoreDiagnostics/Public/*.h',
  ]

  s.framework = 'Foundation'

  s.dependency 'GoogleDataTransport', '~> 7.0'
  s.dependency 'GoogleUtilities/Environment', '~> 6.7'
  s.dependency 'GoogleUtilities/Logger', '~> 6.7'
  s.dependency 'nanopb', '~> 1.30905.0'

  s.test_spec 'unit' do |unit_tests|
    unit_tests.platforms = {:ios => '8.0', :osx => '10.11', :tvos => '10.0'}
    unit_tests.platforms = {:ios => '8.0', :osx => '10.11', :tvos => '10.0'}
    unit_tests.dependency 'GoogleUtilities/UserDefaults', '~> 6.7'
    unit_tests.dependency 'OCMock'
    unit_tests.source_files = [
      'Example/CoreDiagnostics/Tests/**/*.[mh]',
      'GoogleUtilities/UserDefaults/Private/*.h',
    ]
    unit_tests.requires_app_host = false
  end
end
