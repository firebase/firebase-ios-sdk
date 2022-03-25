Pod::Spec.new do |s|
  s.name             = 'FirebaseCrashlytics'
  s.version          = '8.15.0'
  s.summary          = 'Best and lightest-weight crash reporting for mobile, desktop and tvOS.'
  s.description      = 'Firebase Crashlytics helps you track, prioritize, and fix stability issues that erode app quality.'
  s.homepage         = 'https://firebase.google.com/'
  s.license          = { :type => 'Apache', :file => 'Crashlytics/LICENSE' }
  s.authors          = 'Google, Inc.'
  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'CocoaPods-' + s.version.to_s
  }

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

  s.source_files = [
    'Crashlytics/Crashlytics/**/*.{c,h,m,mm}',
    'Crashlytics/Protogen/**/*.{c,h,m,mm}',
    'Crashlytics/Shared/**/*.{c,h,m,mm}',
    'Crashlytics/third_party/**/*.{c,h,m,mm}',
    'FirebaseCore/Sources/Private/*.h',
    'FirebaseInstallations/Source/Library/Private/*.h',
    'Interop/Analytics/Public/*.h',
  ]

  s.public_header_files = [
    'Crashlytics/Crashlytics/Public/FirebaseCrashlytics/*.h'
  ]

  s.preserve_paths = [
    'Crashlytics/README.md',
    'run',
    'upload-symbols',
  ]

  # Ensure the run script and upload-symbols are callable via
  # ${PODS_ROOT}/FirebaseCrashlytics/<name>
  s.prepare_command = <<-PREPARE_COMMAND_END
    cp -f ./Crashlytics/run ./run
    cp -f ./Crashlytics/upload-symbols ./upload-symbols
  PREPARE_COMMAND_END

  s.dependency 'FirebaseCore', '~> 8.0'
  s.dependency 'FirebaseInstallations', '~> 8.0'
  s.dependency 'PromisesObjC', '>= 1.2', '< 3.0'
  s.dependency 'GoogleDataTransport', '~> 9.1'
  s.dependency 'GoogleUtilities/Environment', '~> 7.7'
  s.dependency 'nanopb', '~> 2.30908.0'

  s.libraries = 'c++', 'z'
  s.ios.frameworks = 'Security', 'SystemConfiguration'
  s.macos.frameworks = 'Security', 'SystemConfiguration'
  s.osx.frameworks = 'Security', 'SystemConfiguration'
  s.watchos.frameworks = 'Security'

  s.ios.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'GCC_PREPROCESSOR_DEFINITIONS' =>
      'CLS_SDK_NAME="Crashlytics iOS SDK" ' +
      # For nanopb:
      'PB_FIELD_32BIT=1 PB_NO_PACKED_STRUCTS=1 PB_ENABLE_MALLOC=1',
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}"',
  }

  s.osx.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'GCC_PREPROCESSOR_DEFINITIONS' =>
      'CLS_SDK_NAME="Crashlytics Mac SDK" ' +
      # For nanopb:
      'PB_FIELD_32BIT=1 PB_NO_PACKED_STRUCTS=1 PB_ENABLE_MALLOC=1',
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}"',
  }

  s.tvos.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'GCC_PREPROCESSOR_DEFINITIONS' =>
      'CLS_SDK_NAME="Crashlytics tvOS SDK" ' +
      # For nanopb:
      'PB_FIELD_32BIT=1 PB_NO_PACKED_STRUCTS=1 PB_ENABLE_MALLOC=1',
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}"',
  }

  s.watchos.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'GCC_PREPROCESSOR_DEFINITIONS' =>
      'CLS_SDK_NAME="Crashlytics watchOS SDK" ' +
      # For nanopb:
      'PB_FIELD_32BIT=1 PB_NO_PACKED_STRUCTS=1 PB_ENABLE_MALLOC=1',
    'OTHER_LD_FLAGS' => '$(inherited) -sectcreate __TEXT __info_plist',
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}"',
  }

  s.test_spec 'unit' do |unit_tests|
    unit_tests.scheme = { :code_coverage => true }
    # Unit tests can't run on watchOS.
    unit_tests.platforms = {
      :ios => ios_deployment_target,
      :osx => osx_deployment_target,
      :tvos => tvos_deployment_target
    }
    unit_tests.source_files = 'Crashlytics/UnitTests/*.[mh]',
                              'Crashlytics/UnitTests/*/*.[mh]'
    unit_tests.resources = 'Crashlytics/UnitTests/Data/*',
                           'Crashlytics/UnitTests/*.clsrecord',
                           'Crashlytics/UnitTests/FIRCLSMachO/data/*'
  end
end
