Pod::Spec.new do |s|
  s.name             = 'FirebaseAppDistribution'
  s.version          = '0.0.1'
  s.summary          = 'App Distribution for Firebase iOS SDK.'

  s.description      = <<-DESC
iOS SDK for App Distribution for Firebase.
                       DESC

  s.homepage         = 'https://developers.google.com/'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'
  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'AppDistribution-' + s.version.to_s
  }

  s.ios.deployment_target = '8.0'

  s.cocoapods_version = '>= 1.4.0'
  s.static_framework = true
  s.prefix_header_file = false

  base_dir = "FirebaseAppDistribution/Sources/"
  s.source_files = base_dir + '**/*.{c,h,m,mm}'
  s.public_header_files = base_dir + 'Public/*.h'
  s.private_header_files = base_dir + 'Private/*.h'

  s.dependency 'FirebaseCore', '~> 6.0'
  s.dependency 'AppAuth', '~> 1.2.0'
  s.dependency 'GoogleUtilities/AppDelegateSwizzler'

  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'GCC_PREPROCESSOR_DEFINITIONS' => 'FIRAppDistribution_VERSION=' + s.version.to_s
  }


  s.test_spec 'unit' do |unit_tests|
   unit_tests.source_files = 'FirebaseAppDistribution/Tests/Unit*/*.[mh]'
  end

  # end
end
