Pod::Spec.new do |s|
  s.name             = 'FirebaseInstallations'
  s.version          = '1.5.0'
  s.summary          = 'Firebase Installations'

  s.description      = <<-DESC
  Firebase Installations.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'Installations-' + s.version.to_s
  }
  s.social_media_url = 'https://twitter.com/Firebase'
  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.11'
  s.tvos.deployment_target = '10.0'
  s.watchos.deployment_target = '6.0'

  s.cocoapods_version = '>= 1.4.0'
  s.static_framework = true
  s.prefix_header_file = false

  base_dir = "FirebaseInstallations/Source/"
  s.source_files = [
    base_dir + 'Library/**/*.[mh]',
    'FirebaseCore/Sources/Private/*.h',
    'GoogleUtilities/Environment/Private/*.h',
    'GoogleUtilities/UserDefaults/Private/*.h',
  ]
  s.public_header_files = [
    base_dir + 'Library/Public/*.h',
    base_dir + 'Library/Private/*.h',
  ]
  s.private_header_files = base_dir + 'Library/Private/*.h'

  s.framework = 'Security'
  s.dependency 'FirebaseCore', '~> 6.8'
  s.dependency 'PromisesObjC', '~> 1.2'
  s.dependency 'GoogleUtilities/Environment', '~> 6.7'
  s.dependency 'GoogleUtilities/UserDefaults', '~> 6.7'

  preprocessor_definitions = 'FIRInstallations_LIB_VERSION=' + String(s.version)
  if ENV['FIS_ALLOWS_INCOMPATIBLE_IID_VERSION'] && ENV['FIS_ALLOWS_INCOMPATIBLE_IID_VERSION'] == '1' then
    # Disable FirebaseInstanceID compatibility assert to test IID migration.
    preprocessor_definitions += ' FIR_INSTALLATIONS_ALLOWS_INCOMPATIBLE_IID_VERSION=1'
  end
  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'GCC_PREPROCESSOR_DEFINITIONS' => preprocessor_definitions,
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}"'
  }

  s.test_spec 'unit' do |unit_tests|
    unit_tests.platforms = {:ios => '8.0', :osx => '10.11', :tvos => '10.0'}
    unit_tests.source_files = base_dir + 'Tests/Unit/**/*.[mh]',
                              base_dir + 'Tests/Utils/**/*.[mh]'
    unit_tests.resources = base_dir + 'Tests/Fixture/**/*'
    unit_tests.requires_app_host = true
    unit_tests.dependency 'OCMock'
    unit_tests.dependency 'FirebaseInstanceID', '~> 4.2.0' # The version before FirebaseInstanceID updated to use FirebaseInstallations under the hood.

  end

  s.test_spec 'integration' do |int_tests|
    int_tests.platforms = {:ios => '8.0', :osx => '10.11', :tvos => '10.0'}
    int_tests.source_files = base_dir + 'Tests/Integration/**/*.[mh]'
    int_tests.resources = base_dir + 'Tests/Resources/**/*'
    if ENV['FIS_INTEGRATION_TESTS_REQUIRED'] && ENV['FIS_INTEGRATION_TESTS_REQUIRED'] == '1' then
      int_tests.pod_target_xcconfig = {
      'GCC_PREPROCESSOR_DEFINITIONS' =>
        'FIR_INSTALLATIONS_INTEGRATION_TESTS_REQUIRED=1'
      }
    end
    int_tests.requires_app_host = true
    int_tests.dependency 'OCMock'
  end
end
