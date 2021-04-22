Pod::Spec.new do |s|
  s.name             = 'FirebaseInstanceID'
  s.version          = '8.0.0'
  s.summary          = 'Firebase InstanceID'

  s.description      = <<-DESC
Instance ID provides a unique ID per instance of your iOS apps. In addition to providing
unique IDs for authentication, Instance ID can generate security tokens for use with other
services.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'CocoaPods-' + s.version.to_s
  }
  s.social_media_url = 'https://twitter.com/Firebase'

  ios_deployment_target = '10.0'
  osx_deployment_target = '10.12'
  tvos_deployment_target = '10.0'
  watchos_deployment_target = '6.0'

  s.ios.deployment_target = ios_deployment_target
  s.osx.deployment_target = osx_deployment_target
  s.tvos.deployment_target = tvos_deployment_target
  s.watchos.deployment_target = watchos_deployment_target

  s.cocoapods_version = '>= 1.4.0'
  s.prefix_header_file = false

  base_dir = "Firebase/InstanceID/"
  s.source_files = [
    base_dir + '**/*.[mh]',
    'FirebaseCore/Sources/Private/*.h',
    'FirebaseInstallations/Source/Library/Private/*.h',
  ]
  s.requires_arc = base_dir + '*.m'
  s.public_header_files = base_dir + 'Public/*.h'
  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}"'
  }
  s.framework = 'Security'
  s.dependency 'FirebaseCore', '~> 7.0'
  s.dependency 'FirebaseInstallations', '~> 7.0'
  s.dependency 'GoogleUtilities/UserDefaults', '~> 7.0'
  s.dependency 'GoogleUtilities/Environment', '~> 7.0'

  s.test_spec 'unit' do |unit_tests|
    unit_tests.scheme = { :code_coverage => true }
    unit_tests.platforms = {
      :ios => ios_deployment_target,
      :osx => osx_deployment_target,
      :tvos => tvos_deployment_target
    }
    unit_tests.source_files = 'Example/InstanceID/Tests/*.[mh]'
    unit_tests.requires_app_host = true
    unit_tests.dependency 'OCMock'
    unit_tests.pod_target_xcconfig = {
      # Unit tests do library imports using repo-root relative paths.
      'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}"',
      # Prevent linker warning for test category override of
      # store:didDeleteFCMScopedTokensForCheckin:
      'OTHER_LDFLAGS' => '-Xlinker -no_objc_category_merging',
      'CLANG_ENABLE_OBJC_WEAK' => 'YES'
    }
  end

   s.test_spec 'integration' do |int_tests|
    int_tests.scheme = { :code_coverage => true }
    int_tests.platforms = {
      :ios => ios_deployment_target,
      :osx => osx_deployment_target,
      :tvos => tvos_deployment_target
    }
    int_tests.source_files = 'Example/InstanceID/IntegrationTests/*.[mh]'
    int_tests.resources = 'Example/InstanceID/Resources/**/*'
    int_tests.requires_app_host = true
    if ENV['FIR_IID_INTEGRATION_TESTS_REQUIRED'] && ENV['FIR_IID_INTEGRATION_TESTS_REQUIRED'] == '1' then
      int_tests.pod_target_xcconfig = {
      'GCC_PREPROCESSOR_DEFINITIONS' =>
        'FIR_IID_INTEGRATION_TESTS_REQUIRED=1'
      }
    end
  end

end
