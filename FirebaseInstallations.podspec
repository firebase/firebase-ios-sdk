Pod::Spec.new do |s|
  s.name             = 'FirebaseInstallations'
  s.version          = '11.5.0'
  s.summary          = 'Firebase Installations'

  s.description      = <<-DESC
  Firebase Installations.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache-2.0', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'CocoaPods-' + s.version.to_s
  }
  s.social_media_url = 'https://twitter.com/Firebase'

  ios_deployment_target = '12.0'
  osx_deployment_target = '10.15'
  tvos_deployment_target = '13.0'
  watchos_deployment_target = '7.0'

  s.swift_version = '5.9'

  s.ios.deployment_target = ios_deployment_target
  s.osx.deployment_target = osx_deployment_target
  s.tvos.deployment_target = tvos_deployment_target
  s.watchos.deployment_target = watchos_deployment_target

  s.cocoapods_version = '>= 1.12.0'
  s.prefix_header_file = false

  base_dir = "FirebaseInstallations/Source/"
  s.source_files = [
    base_dir + 'Library/**/*.[mh]',
    'FirebaseCore/Extension/*.h',
  ]
  s.public_header_files = [
    base_dir + 'Library/Public/FirebaseInstallations/*.h',
  ]
  s.resource_bundles = {
    "#{s.module_name}_Privacy" => 'FirebaseInstallations/Source/Library/Resources/PrivacyInfo.xcprivacy'
  }

  s.framework = 'Security'
  s.dependency 'FirebaseCore', '11.5'
  s.dependency 'PromisesObjC', '~> 2.4'
  s.dependency 'GoogleUtilities/Environment', '~> 8.0'
  s.dependency 'GoogleUtilities/UserDefaults', '~> 8.0'

  preprocessor_definitions = ''
  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'GCC_PREPROCESSOR_DEFINITIONS' => preprocessor_definitions,
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}"'
  }

  s.test_spec 'unit' do |unit_tests|
    unit_tests.scheme = { :code_coverage => true }
    unit_tests.platforms = {
      :ios => ios_deployment_target,
      :osx => '10.15',
      :tvos => tvos_deployment_target
    }
    unit_tests.source_files = base_dir + 'Tests/Unit/*.[mh]',
                              base_dir + 'Tests/Utils/*.[mh]',
                              base_dir + 'Tests/Unit/Swift/*'
    unit_tests.resources = base_dir + 'Tests/Fixture/**/*'
    unit_tests.requires_app_host = true
    unit_tests.dependency 'OCMock'

    if ENV['FIS_IID_MIGRATION_TESTING'] && ENV['FIS_IID_MIGRATION_TESTING'] == '1' then
      unit_tests.source_files += base_dir + 'Tests/Unit/IIDStoreTests/*.[mh]'
    end
  end

  s.test_spec 'integration' do |int_tests|
    int_tests.scheme = { :code_coverage => true }
    int_tests.platforms = {:ios => '10.0', :osx => '10.15', :tvos => '11.0'}
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
