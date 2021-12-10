Pod::Spec.new do |s|
  s.name             = 'FirebaseAppDistribution'
  s.version          = '8.10.0-beta'
  s.summary          = 'App Distribution for Firebase iOS SDK.'

  s.description      = <<-DESC
iOS SDK for App Distribution for Firebase.
                       DESC

  s.homepage         = 'https://developers.google.com/'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'
  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'CocoaPods-' + s.version.to_s
  }

  s.ios.deployment_target = '10.0'

  s.cocoapods_version = '>= 1.4.0'
  s.prefix_header_file = false

  base_dir = "FirebaseAppDistribution/Sources/"
  s.source_files = [
    base_dir + '**/*.{c,h,m,mm}',
    'FirebaseCore/Sources/Private/*.h',
    'FirebaseInstallations/Source/Library/Private/*.h',
  ]
  s.public_header_files = base_dir + 'Public/FirebaseAppDistribution/*.h'

  s.dependency 'FirebaseCore', '~> 8.0'
  s.dependency 'GoogleUtilities/AppDelegateSwizzler', '~> 7.6'
  s.dependency 'GoogleUtilities/UserDefaults', '~> 7.6'
  s.dependency 'FirebaseInstallations', '~> 8.0'
  s.dependency 'GoogleDataTransport', '~> 9.1'

  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}"'
  }

  s.test_spec 'unit' do |unit_tests|
   unit_tests.scheme = { :code_coverage => true }
   unit_tests.source_files = 'FirebaseAppDistribution/Tests/Unit*/*.[mh]'
   unit_tests.resources = 'FirebaseAppDistribution/Tests/Unit/Resources/*'
   unit_tests.dependency 'OCMock'
  end

  # end
end
