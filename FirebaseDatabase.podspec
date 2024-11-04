Pod::Spec.new do |s|
  s.name             = 'FirebaseDatabase'
  s.version          = '11.5.0'
  s.summary          = 'Firebase Realtime Database'

  s.description      = <<-DESC
Simplify your iOS development, grow your user base, and monetize more effectively with Firebase.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache-2.0', :file => 'FirebaseDatabase/LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'CocoaPods-' + s.version.to_s
  }
  s.social_media_url = 'https://twitter.com/Firebase'

  ios_deployment_target = '13.0'
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

  base_dir = "FirebaseDatabase/Sources/"
  s.source_files = [
    base_dir + '**/*.[mh]',
    base_dir + 'third_party/Wrap-leveldb/APLevelDB.mm',
    'FirebaseDatabase/Swift/Sources/**/*.swift',
    'FirebaseAuth/Interop/**/*.h',
    'FirebaseCore/Extension/*.h',
  ]
  s.public_header_files = base_dir + 'Public/FirebaseDatabase/*.h'
  s.libraries = ['c++', 'icucore']
  s.ios.frameworks = 'CFNetwork', 'Security', 'SystemConfiguration'
  s.tvos.frameworks = 'CFNetwork', 'Security', 'SystemConfiguration'
  s.macos.frameworks = 'CFNetwork', 'Security', 'SystemConfiguration'
  s.watchos.frameworks = 'CFNetwork', 'Security', 'WatchKit'
  s.dependency 'leveldb-library', '~> 1.22'
  s.dependency 'FirebaseCore', '11.5'
  s.dependency 'FirebaseAppCheckInterop', '~> 11.0'
  s.dependency 'FirebaseSharedSwift', '~> 11.0'
  s.dependency 'GoogleUtilities/UserDefaults', '~> 8.0'
  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}"'
  }

  s.test_spec 'unit' do |unit_tests|
    unit_tests.platforms = {
      :ios => ios_deployment_target,
      :osx => osx_deployment_target,
      :tvos => tvos_deployment_target
    }
    unit_tests.scheme = { :code_coverage => true }
    unit_tests.source_files = [
      'FirebaseDatabase/Tests/Unit/*.[mh]',
      'FirebaseDatabase/Tests/Unit/Swift/*',
      'FirebaseDatabase/Tests/Helpers/*.[mh]',
      'SharedTestUtilities/AppCheckFake/*.[mh]',
      'SharedTestUtilities/FIRAuthInteropFake.[mh]',
      'SharedTestUtilities/FIRComponentTestUtilities.[mh]',
      'SharedTestUtilities/FIROptionsMock.[mh]',
    ]
    unit_tests.dependency 'FirebaseAppCheckInterop', '~> 11.0'
    unit_tests.dependency 'OCMock'
    unit_tests.resources = 'FirebaseDatabase/Tests/Resources/syncPointSpec.json',
                           'FirebaseDatabase/Tests/Resources/GoogleService-Info.plist'
  end

  s.test_spec 'integration' do |int_tests|
    int_tests.platforms = {:ios => ios_deployment_target, :osx => osx_deployment_target, :tvos => tvos_deployment_target}
    int_tests.scheme = { :code_coverage => true }
    int_tests.requires_app_host = true
    int_tests.source_files = [
      'FirebaseDatabase/Tests/Integration/*.[mh]',
      'FirebaseDatabase/Tests/Helpers/*.[mh]',
      'SharedTestUtilities/AppCheckFake/*.[mh]',
      'SharedTestUtilities/FIRAuthInteropFake.[mh]',
      'SharedTestUtilities/FIRComponentTestUtilities.[mh]',
      'SharedTestUtilities/FIROptionsMock.[mh]',
    ]
    int_tests.dependency 'OCMock'
    int_tests.resources = 'FirebaseDatabase/Tests/Resources/GoogleService-Info.plist'
  end
end
