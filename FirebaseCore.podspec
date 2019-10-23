Pod::Spec.new do |s|
  s.name             = 'FirebaseCore'
  s.version          = '6.3.2'
  s.summary          = 'Firebase Core for iOS (plus community support for macOS and tvOS)'

  s.description      = <<-DESC
Firebase Core includes FIRApp and FIROptions which provide central configuration for other Firebase services.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'Core-' + s.version.to_s
  }
  s.social_media_url = 'https://twitter.com/Firebase'
  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.11'
  s.tvos.deployment_target = '10.0'

  s.cocoapods_version = '>= 1.4.0'
  s.static_framework = true
  s.prefix_header_file = false

  s.source_files = 'Firebase/Core/**/*.[cmh]'
  s.public_header_files = 'Firebase/Core/Public/*.h', 'Firebase/Core/Private/*.h'
  s.private_header_files = 'Firebase/Core/Private/*.h'
  s.framework = 'Foundation'
  s.ios.framework = 'UIKit'
  s.osx.framework = 'AppKit'
  s.tvos.framework = 'UIKit'
  s.dependency 'GoogleUtilities/Environment', '~> 6.2'
  s.dependency 'GoogleUtilities/Logger', '~> 6.2'
  s.dependency 'GoogleDataTransportCCTSupport', '~> 1.0'
  s.dependency 'nanopb', '~> 0.3.901'

  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'GCC_TREAT_WARNINGS_AS_ERRORS' => 'YES',
    'GCC_PREPROCESSOR_DEFINITIONS' =>
      'FIRCore_VERSION=' + s.version.to_s + ' Firebase_VERSION=6.11.0 ' +
      # The nanopb pod sets these defs, so we must too. (We *do* require 16bit
      # (or larger) fields, so we'd have to set at least PB_FIELD_16BIT
      # anyways.)
      'PB_FIELD_32BIT=1 PB_NO_PACKED_STRUCTS=1 PB_ENABLE_MALLOC=1',
    'OTHER_CFLAGS' => '-fno-autolink',
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}"'
  }
  s.test_spec 'unit' do |unit_tests|
    unit_tests.source_files = 'Example/Core/Tests/**/*.[mh]'
    unit_tests.dependency 'GoogleUtilities/UserDefaults', '~> 6.2'
    unit_tests.requires_app_host = true
    unit_tests.dependency 'OCMock'
    unit_tests.resources = 'Example/Core/App/GoogleService-Info.plist'
  end
end
