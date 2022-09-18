Pod::Spec.new do |s|
  s.name             = 'FirebasePerformance'
  s.version          = '9.6.0'
  s.summary          = 'Firebase Performance'

  s.description      = <<-DESC
Firebase Performance library to measure performance of Mobile and Web Apps.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache-2.0', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'CocoaPods-' + s.version.to_s
  }
  s.social_media_url = 'https://twitter.com/Firebase'

  ios_deployment_target = '10.0'
  tvos_deployment_target = '10.0'

  s.swift_version = '5.3'

  s.ios.deployment_target = ios_deployment_target
  s.tvos.deployment_target = tvos_deployment_target

  s.cocoapods_version = '>= 1.4.0'
  s.prefix_header_file = false

  base_dir = "FirebasePerformance/"
  s.source_files = [
    base_dir + 'Sources/**/*.[cmh]',
    'FirebaseCore/Extension/*.h',
    'FirebaseInstallations/Source/Library/Private/*.h',
    'FirebaseRemoteConfig/Sources/Private/*.h',
  ]

  s.requires_arc = [
    base_dir + 'Sources/**/*.[mh]',
    base_dir + 'Public/**/*.h',
  ]

  s.public_header_files = base_dir + 'Sources/Public/FirebasePerformance/*.h'

  preprocessor_definitions = 'FIRPerformance_LIB_VERSION=' + String(s.version)
  preprocessor_definitions += ' PB_FIELD_32BIT=1 PB_NO_PACKED_STRUCTS=1 PB_ENABLE_MALLOC=1'
  if ENV['FPR_UNSWIZZLE_AVAILABLE'] && ENV['FPR_UNSWIZZLE_AVAILABLE'] == '1' then
    preprocessor_definitions += ' UNSWIZZLE_AVAILABLE=1'
  end

  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'GCC_PREPROCESSOR_DEFINITIONS' => preprocessor_definitions,
    # Unit tests do library imports using repo-root relative paths.
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}"',
  }

  s.ios.framework = 'CoreTelephony'
  s.framework = 'QuartzCore'
  s.framework = 'SystemConfiguration'
  s.dependency 'FirebaseCore', '~> 9.0'
  s.dependency 'FirebaseInstallations', '~> 9.0'
  s.dependency 'FirebaseRemoteConfig', '~> 9.0'
  s.dependency 'GoogleDataTransport', '>= 9.1.4', '< 10.0.0'
  s.dependency 'GoogleUtilities/Environment', '~> 7.7'
  s.dependency 'GoogleUtilities/ISASwizzler', '~> 7.7'
  s.dependency 'GoogleUtilities/MethodSwizzler', '~> 7.7'
  s.dependency 'nanopb', '>= 2.30908.0', '< 2.30910.0'

  s.test_spec 'unit' do |unit_tests|
    unit_tests.platforms = {:ios => ios_deployment_target, :tvos => tvos_deployment_target}
    unit_tests.scheme = { :code_coverage => true }
    unit_tests.source_files = [
      'FirebasePerformance/Tests/Unit/**/*.{m,h,plist}',
      'SharedTestUtilities/*.[hm]',
    ]
    unit_tests.resources = ['FirebasePerformance/Tests/Unit/Server/*File']
    unit_tests.requires_arc = true
    unit_tests.requires_app_host = true
    unit_tests.pod_target_xcconfig = {
     'CLANG_ENABLE_OBJC_WEAK' => 'YES',
    }
    unit_tests.info_plist = {
      'FPRTestingDummyFeature' => true,
      'FPRScreenTracesForContainerVC' => true,
      'FPRDelegateSwizzling' => true,
      'FPRNSURLConnection' => true,
      'FPRScreenTracesSwizzling' => true,
      'FPRScreenTraces' => false,
    }

    unit_tests.dependency 'GoogleUtilities/SwizzlerTestHelpers'
    unit_tests.dependency 'OCMock'
    unit_tests.dependency 'GCDWebServer'
  end

  s.app_spec 'TestApp' do |app_spec|
    app_spec.platforms = {:ios => ios_deployment_target, :tvos => tvos_deployment_target}
    app_spec.source_files = ['FirebasePerformance/Tests/TestApp/Source/**/*.{m,h}']
    ios_resources = ['FirebasePerformance/Tests/TestApp/Resources/*.*']
    if ENV['FPR_AUTOPUSH_ENV'] && ENV['FPR_AUTOPUSH_ENV'] == '1' then
      ios_resources += ['FirebasePerformance/Tests/TestApp/Plists/Autopush/**/*.plist']
      app_spec.info_plist = {
        'CFBundleIdentifier' => 'com.google.FIRPerfTestAppAutopush'
      }
      app_spec.scheme = {
        :environment_variables => { "FPR_AUTOPUSH_ENV" => "1" }
      }
    else
      ios_resources += ['FirebasePerformance/Tests/TestApp/Plists/Prod/**/*.plist']
      app_spec.info_plist = {
        'CFBundleIdentifier' => 'com.google.FIRPerfTestApp'
      }
    end
    app_spec.ios.resources = ios_resources
    app_spec.requires_arc = true
  end

end
