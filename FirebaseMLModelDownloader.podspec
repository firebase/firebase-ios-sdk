Pod::Spec.new do |s|
  s.name             = 'FirebaseMLModelDownloader'
  s.version          = '11.5.0-beta'
  s.summary          = 'Firebase ML Model Downloader'

  s.description      = <<-DESC
  This is the new ML Model Downloader CocoaPod.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache-2.0', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'CocoaPods-' + s.version.to_s
  }
  s.social_media_url = 'https://twitter.com/Firebase'
  s.swift_version = '5.9'

  ios_deployment_target = '13.0'
  osx_deployment_target = '10.15'
  tvos_deployment_target = '13.0'
  watchos_deployment_target = '7.0'

  s.ios.deployment_target = ios_deployment_target
  s.osx.deployment_target = osx_deployment_target
  s.tvos.deployment_target = tvos_deployment_target
  s.watchos.deployment_target = watchos_deployment_target

  s.cocoapods_version = '>= 1.12.0'
  s.prefix_header_file = false

  s.source_files = [
    'FirebaseMLModelDownloader/Sources/**/*.swift',
  ]

  s.framework = 'Foundation'
  s.dependency 'FirebaseCore', '11.5'
  s.dependency 'FirebaseCoreExtension', '11.5'
  s.dependency 'FirebaseInstallations', '~> 11.0'
  s.dependency 'GoogleDataTransport', '~> 10.0'
  s.dependency 'GoogleUtilities/UserDefaults', '~> 8.0'
  s.dependency 'SwiftProtobuf', '~> 1.19'

  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'GCC_PREPROCESSOR_DEFINITIONS' => 'FIRMLModelDownloader_VERSION=' + s.version.to_s,
    'OTHER_CFLAGS' => '-fno-autolink',
  }

  s.test_spec 'unit' do |unit_tests|
    unit_tests.scheme = { :code_coverage => true }
    unit_tests.platforms = {:ios => ios_deployment_target, :osx => osx_deployment_target, :tvos => tvos_deployment_target}
    unit_tests.source_files = 'FirebaseMLModelDownloader/Tests/Unit/**/*.swift'
    unit_tests.requires_app_host = true
  end

  s.test_spec 'integration' do |int_tests|
    int_tests.scheme = { :code_coverage => true }
    int_tests.platforms = {:ios => ios_deployment_target, :osx => osx_deployment_target, :tvos => tvos_deployment_target}
    int_tests.source_files = 'FirebaseMLModelDownloader/Tests/Integration/**/*.swift'
    int_tests.resources = 'FirebaseMLModelDownloader/Tests/Integration/Resources/GoogleService-Info.plist'
    int_tests.requires_app_host = true
  end
end
