Pod::Spec.new do |s|
  s.name             = 'FirebaseStorage'
  s.version          = '9.6.0'
  s.summary          = 'Firebase Storage'

  s.description      = <<-DESC
Firebase Storage provides robust, secure file uploads and downloads from Firebase SDKs, powered by Google Cloud Storage.
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
  osx_deployment_target = '10.12'
  tvos_deployment_target = '10.0'
  watchos_deployment_target = '6.0'

  s.ios.deployment_target = ios_deployment_target
  s.osx.deployment_target = osx_deployment_target
  s.tvos.deployment_target = tvos_deployment_target
  s.watchos.deployment_target = watchos_deployment_target

  s.swift_version = '5.3'

  s.cocoapods_version = '>= 1.4.0'
  s.prefix_header_file = false

  s.source_files = [
    'FirebaseStorage/Sources/*.swift',
    'FirebaseStorage/Typedefs/*.h',
  ]

  s.dependency 'FirebaseStorageInternal', '~> 9.0'
  s.dependency 'FirebaseAppCheckInterop', '~> 9.0'
  s.dependency 'FirebaseAuthInterop', '~> 9.0'
  s.dependency 'FirebaseCore', '~> 9.0'
  s.dependency 'FirebaseCoreExtension', '~> 9.0'

  s.test_spec 'ObjCIntegration' do |objc_tests|
    objc_tests.scheme = { :code_coverage => true }
    objc_tests.platforms = {
      :ios => ios_deployment_target,
      :osx => osx_deployment_target,
      :tvos => tvos_deployment_target
    }
    objc_tests.source_files = [
      'FirebaseStorageInternal/Tests/Integration/*.[mh]',
      'FirebaseStorage/Tests/ObjCIntegration/*.{m,mm}',
    ]
    objc_tests.requires_app_host = true
    objc_tests.resources = 'FirebaseStorageInternal/Tests/Integration/Resources/1mb.dat',
                          'FirebaseStorageInternal/Tests/Integration/Resources/GoogleService-Info.plist'
    objc_tests.dependency 'FirebaseAuth', '~> 9.0'
    objc_tests.pod_target_xcconfig = {
      'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}"'
    }
  end

  s.test_spec 'unit' do |unit_tests|
    unit_tests.scheme = { :code_coverage => true }
    unit_tests.platforms = {
      :ios => ios_deployment_target,
      :osx => osx_deployment_target,
      :tvos => tvos_deployment_target
    }
    unit_tests.source_files = 'FirebaseStorage/Tests/Unit/StorageAPITests.swift'
  end

  s.test_spec 'integration' do |int_tests|
    int_tests.scheme = { :code_coverage => true }
    int_tests.platforms = {
      :ios => ios_deployment_target,
      :osx => osx_deployment_target,
      :tvos => tvos_deployment_target
    }
    int_tests.source_files = 'FirebaseStorage/Tests/Integration/*.swift'
    int_tests.requires_app_host = true
    int_tests.resources = 'FirebaseStorageInternal/Tests/Integration/Resources/1mb.dat',
                          'FirebaseStorageInternal/Tests/Integration/Resources/GoogleService-Info.plist',
                          'FirebaseStorageInternal/Tests/Integration/Resources/HomeImprovement.numbers'
    int_tests.dependency 'FirebaseAuth', '~> 9.0'
  end
end
