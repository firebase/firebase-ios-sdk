Pod::Spec.new do |s|
  s.name             = 'FirebaseStorageObjC'
  s.version          = '8.13.0'
  s.summary          = 'Firebase Storage'

  s.description      = <<-DESC
Objective C Implementations for FirebaseStorage. This pod should not be directly imported.
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

  s.source_files = [
    'FirebaseStorage/Sources/**/*.[mh]',
    'FirebaseCore/Sources/Private/*.h',
  ]
  s.public_header_files = 'FirebaseStorage/Sources/Public/FirebaseStorage/*.h'

  s.osx.framework = 'CoreServices'

  s.dependency 'FirebaseCore', '~> 8.13'
  s.dependency 'FirebaseAppCheckInterop', '~> 8.13'
  s.dependency 'FirebaseAuthInterop', '~> 8.13'
  s.dependency 'GTMSessionFetcher/Core', '~> 1.5'
  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}"'
  }

  s.test_spec 'unit' do |unit_tests|
    unit_tests.scheme = { :code_coverage => true }
    unit_tests.platforms = {
      :ios => ios_deployment_target,
      :osx => osx_deployment_target,
      :tvos => tvos_deployment_target
    }
    unit_tests.source_files = [
      'FirebaseStorage/Tests/Unit/*.[mh]',
      'SharedTestUtilities/FIRComponentTestUtilities.*',
      'SharedTestUtilities/FIRAuthInteropFake.*',
      'SharedTestUtilities/AppCheckFake/*.[mh]',
  ]
    unit_tests.dependency 'OCMock'
  end
end
