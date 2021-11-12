Pod::Spec.new do |s|
  s.name             = 'FirebaseStorage'
  s.version          = '8.10.0'
  s.summary          = 'Firebase Storage'

  s.description      = <<-DESC
Firebase Storage provides robust, secure file uploads and downloads from Firebase SDKs, powered by Google Cloud Storage.
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
    'Interop/Auth/Public/*.h',
    'FirebaseCore/Sources/Private/*.h',
    'FirebaseAppCheck/Sources/Interop/*.h',
  ]
  s.public_header_files = 'FirebaseStorage/Sources/Public/FirebaseStorage/*.h'

  s.osx.framework = 'CoreServices'

  s.dependency 'FirebaseCore', '~> 8.0'
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

  s.test_spec 'integration' do |int_tests|
    int_tests.scheme = { :code_coverage => true }
    int_tests.platforms = {
      :ios => ios_deployment_target,
      :osx => osx_deployment_target,
      :tvos => tvos_deployment_target
    }
    int_tests.source_files = 'FirebaseStorage/Tests/Integration/*.[mh]'
    int_tests.requires_app_host = true
    int_tests.resources = 'FirebaseStorage/Tests/Integration/Resources/1mb.dat',
                          'FirebaseStorage/Tests/Integration/Resources/GoogleService-Info.plist'
    int_tests.dependency 'FirebaseAuth', '~> 8.0'
  end

  s.test_spec 'swift-integration' do |swift_int_tests|
    swift_int_tests.platforms = {:ios => '10.0', :osx => '10.12', :tvos => '10.0'}
    swift_int_tests.source_files = 'FirebaseStorage/Tests/SwiftIntegration/*.swift'
    swift_int_tests.requires_app_host = true
    swift_int_tests.resources = 'FirebaseStorage/Tests/Integration/Resources/1mb.dat',
                          'FirebaseStorage/Tests/Integration/Resources/GoogleService-Info.plist'
    swift_int_tests.dependency 'FirebaseAuth', '~> 8.0'
  end
end
