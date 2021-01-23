Pod::Spec.new do |s|
  s.name             = 'FirebaseMLModelDownloader'
  s.version          = '7.0.0'
  s.summary          = 'Firebase ML Model Downloader'

  s.description      = <<-DESC
  This is the new ML Model Downloader CocoaPod.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'MLModelDownloader-' + s.version.to_s
  }
  s.social_media_url = 'https://twitter.com/Firebase'
  s.swift_version = '5.0'
  s.ios.deployment_target = '10.0'
  s.osx.deployment_target = '10.12'
  s.tvos.deployment_target = '10.0'
  s.watchos.deployment_target = '6.0'

  s.cocoapods_version = '>= 1.4.0'
  s.static_framework = true
  s.prefix_header_file = false

  s.source_files = [
    'FirebaseMLModelDownloader/Sources/**/*.swift',
  ]

  s.framework = 'Foundation'
  s.dependency 'FirebaseCore', '~> 7.0'
  s.dependency 'FirebaseInstallations', '~> 7.0'
  # TODO: Revisit this dependency
  s.dependency 'SwiftProtobuf', '~> 1.0'

  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'GCC_PREPROCESSOR_DEFINITIONS' => 'FIRMLModelDownloader_VERSION=' + s.version.to_s,
    'OTHER_CFLAGS' => '-fno-autolink',
  }

  s.test_spec 'unit' do |unit_tests|
    unit_tests.scheme = { :code_coverage => true }
    unit_tests.platforms = {:ios => '10.0', :osx => '10.12', :tvos => '10.0'}
    unit_tests.source_files = 'FirebaseMLModelDownloader/Tests/Unit/**/*.swift'
    unit_tests.requires_app_host = true
  end

  s.test_spec 'integration' do |int_tests|
    int_tests.scheme = { :code_coverage => true }
    int_tests.platforms = {:ios => '10.0', :osx => '10.12', :tvos => '10.0'}
    int_tests.source_files = 'FirebaseMLModelDownloader/Tests/Integration/**/*.swift'
    int_tests.resources = 'FirebaseMLModelDownloader/Tests/Integration/Resources/GoogleService-Info.plist'
    int_tests.requires_app_host = true
  end
end
