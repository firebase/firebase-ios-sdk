Pod::Spec.new do |s|
  s.name             = 'FirebaseCore'
  s.version          = '6.4.0'
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
  s.watchos.deployment_target = '6.0'

  s.cocoapods_version = '>= 1.4.0'
  s.static_framework = true
  s.prefix_header_file = false

  s.source_files = 'Firebase/Core/**/*.[mh]'
  s.public_header_files = 'Firebase/Core/Public/*.h', 'Firebase/Core/Private/*.h'
  s.private_header_files = 'Firebase/Core/Private/*.h'
  s.framework = 'Foundation'
  s.ios.framework = 'UIKit'
  s.osx.framework = 'AppKit'
  s.tvos.framework = 'UIKit'
  s.dependency 'GoogleUtilities/Environment', '~> 6.4'
  s.dependency 'GoogleUtilities/Logger', '~> 6.4'
  s.dependency 'FirebaseCoreDiagnosticsInterop', '~> 1.0'
  s.dependency 'FirebaseCoreDiagnostics', '~> 1.0'

  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'GCC_PREPROCESSOR_DEFINITIONS' =>
      'FIRCore_VERSION=' + s.version.to_s + ' Firebase_VERSION=6.13.0',
    'OTHER_CFLAGS' => '-fno-autolink'
  }
  s.test_spec 'unit' do |unit_tests|
    unit_tests.platforms = {:ios => '8.0', :osx => '10.11', :tvos => '10.0'}
    unit_tests.source_files = 'Example/Core/Tests/**/*.[mh]'
    unit_tests.requires_app_host = true
    unit_tests.dependency 'OCMock'
    unit_tests.resources = 'Example/Core/App/GoogleService-Info.plist'
  end

  s.test_spec 'swift-unit' do |swift_unit_tests|
    swift_unit_tests.source_files = 'Example/Core/Tests/Swift/**/*.swift',
                                    'Example/Core/Tests/Swift/**/*.h'
    swift_unit_tests.pod_target_xcconfig = {
      'SWIFT_OBJC_BRIDGING_HEADER' => '$(PODS_TARGET_SRCROOT)/Example/Core/Tests/Swift/FirebaseCore-iOS-Unit-swift-unit-Bridging-Header.h'
    }
  end
end
