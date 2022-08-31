Pod::Spec.new do |s|
  s.name             = 'FirebaseAppDistribution'
  s.version          = '9.6.0-beta'
  s.summary          = 'App Distribution for Firebase iOS SDK.'

  s.description      = <<-DESC
iOS SDK for App Distribution for Firebase.
                       DESC

  s.homepage         = 'https://developers.google.com/'
  s.license          = { :type => 'Apache-2.0', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'
  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'CocoaPods-' + s.version.to_s
  }

  s.ios.deployment_target = '10.0'

  s.swift_version = '5.3'

  s.cocoapods_version = '>= 1.4.0'
  s.prefix_header_file = false

  base_dir = "FirebaseAppDistribution/Sources/"
  s.source_files = [
    base_dir + '**/*.{c,h,m,mm}',
    'FirebaseCore/Extension/*.h',
    'FirebaseInstallations/Source/Library/Private/*.h',
  ]
  s.public_header_files = base_dir + 'Public/FirebaseAppDistribution/*.h'

  s.dependency 'FirebaseCore', '~> 9.0'
  s.dependency 'GoogleUtilities/AppDelegateSwizzler', '~> 7.7'
  s.dependency 'GoogleUtilities/UserDefaults', '~> 7.7'
  s.dependency 'FirebaseInstallations', '~> 9.0'
  s.dependency 'GoogleDataTransport', '>= 9.1.4', '< 10.0.0'

  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}"'
  }

  s.test_spec 'unit' do |unit_tests|
   unit_tests.scheme = { :code_coverage => true }
   unit_tests.source_files = [
     'FirebaseAppDistribution/Tests/Unit*/*.[mh]',
     'FirebaseAppDistribution/Tests/Unit/Swift*/*.swift',
   ]
   unit_tests.resources = 'FirebaseAppDistribution/Tests/Unit/Resources/*'
   unit_tests.dependency 'OCMock'
  end

end
