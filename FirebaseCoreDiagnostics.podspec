Pod::Spec.new do |s|
  s.name             = 'FirebaseCoreDiagnostics'
  s.version          = '8.15.0'
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
    :tag => 'CocoaPods-' + s.version.to_s
  }

  s.social_media_url = 'https://twitter.com/Firebase'

  ios_deployment_target = '9.0'
  osx_deployment_target = '10.12'
  tvos_deployment_target = '10.0'
  watchos_deployment_target = '6.0'

  s.ios.deployment_target = ios_deployment_target
  s.osx.deployment_target = osx_deployment_target
  s.tvos.deployment_target = tvos_deployment_target
  s.watchos.deployment_target = watchos_deployment_target

  s.cocoapods_version = '>= 1.4.0'
  s.prefix_header_file = false

  header_search_paths = {
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}"'
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
    'Interop/CoreDiagnostics/Public/*.h',
  ]
  s.public_header_files = 'Firebase/CoreDiagnostics/FIRCDLibrary/Public/*.h'

  s.framework = 'Foundation'

  s.dependency 'GoogleDataTransport', '~> 9.1'
  s.dependency 'GoogleUtilities/Environment', '~> 7.7'
  s.dependency 'GoogleUtilities/Logger', '~> 7.7'
  s.dependency 'nanopb', '~> 2.30908.0'

  s.test_spec 'unit' do |unit_tests|
    unit_tests.scheme = { :code_coverage => true }
    unit_tests.platforms = {
      :ios => ios_deployment_target,
      :osx => osx_deployment_target,
      :tvos => tvos_deployment_target
    }
    unit_tests.dependency 'GoogleUtilities/UserDefaults', '~> 7.7'
    unit_tests.dependency 'OCMock'
    unit_tests.source_files = [
      'Example/CoreDiagnostics/Tests/**/*.[mh]',
    ]
    unit_tests.requires_app_host = false
  end
end
