Pod::Spec.new do |s|
  s.name             = 'FirebaseCrashlytics'
  s.version          = '4.0.0-beta.2'
  s.summary          = 'Best and lightest-weight crash reporting for mobile, desktop and tvOS.'
  s.description      = 'Firebase Crashlytics helps you track, prioritize, and fix stability issues that erode app quality.'
  s.homepage         = 'https://firebase.google.com/'
  s.license          = { :type => 'Apache', :file => 'Crashlytics/LICENSE' }
  s.authors          = 'Google, Inc.'
  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'Crashlytics-' + s.version.to_s
  }

  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.11'
  s.tvos.deployment_target = '10.0'

  s.cocoapods_version = '>= 1.4.0'
  s.static_framework = true
  s.prefix_header_file = false

  s.source_files = 'Crashlytics/Crashlytics/**/*.{c,h,m,mm}',
    'Crashlytics/Shared/**/*.{c,h,m,mm}',
    'Crashlytics/third_party/**/*.{c,h,m,mm}'

  s.public_header_files = [
    'Crashlytics/Crashlytics/Public/*.h'
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

  s.dependency 'FirebaseCore', '~> 6.6'
  s.dependency 'FirebaseInstanceID', '~> 4.3'
  s.dependency 'FirebaseAnalyticsInterop', '~> 1.2'
  s.dependency 'PromisesObjC', '~> 1.2'
  s.dependency 'GoogleDataTransport', '~> 3.2'
  s.dependency 'nanopb', '~> 0.3.901'

  s.libraries = 'c++', 'z'
  s.frameworks = 'Security', 'SystemConfiguration'

  s.ios.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'GCC_PREPROCESSOR_DEFINITIONS' =>
      'DISPLAY_VERSION=' + s.version.to_s + ' ' +
      'CLS_SDK_NAME="Crashlytics iOS SDK" ' +
      # For FireLog:
      'PB_FIELD_32BIT=1 PB_NO_PACKED_STRUCTS=1 PB_ENABLE_MALLOC=1 GDTCCTSUPPORT_VERSION=' + s.version.to_s,
    'OTHER_LD_FLAGS' => '$(inherited) -sectcreate __TEXT __info_plist'
  }

  s.osx.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'GCC_PREPROCESSOR_DEFINITIONS' =>
      'DISPLAY_VERSION=' + s.version.to_s + ' ' +
      'CLS_SDK_NAME="Crashlytics Mac SDK" ',
    'OTHER_LD_FLAGS' => '$(inherited) -sectcreate __TEXT __info_plist'
  }

  s.tvos.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'GCC_PREPROCESSOR_DEFINITIONS' =>
      'DISPLAY_VERSION=' + s.version.to_s + ' ' +
      'CLS_SDK_NAME="Crashlytics tvOS SDK" ',
    'OTHER_LD_FLAGS' => '$(inherited) -sectcreate __TEXT __info_plist'
  }

  s.test_spec 'unit' do |unit_tests|
    unit_tests.source_files = 'Crashlytics/UnitTests/*.[mh]',
                              'Crashlytics/UnitTests/*/*.[mh]'
    unit_tests.resources = 'Crashlytics/UnitTests/Data/*',
                           'Crashlytics/UnitTests/*.clsrecord',
                           'Crashlytics/UnitTests/FIRCLSMachO/data/*'
  end
end
