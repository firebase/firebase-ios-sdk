Pod::Spec.new do |s|
  s.name             = 'GoogleDataLogger'
  s.version          = '0.1.0'
  s.summary          = 'Google Data Logging iOS SDK.'


  s.description      = <<-DESC
Shared library for iOS SDK data logging needs.
                       DESC

  s.homepage         = 'https://developers.google.com/'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'
  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'GoogleDataLogger-' + s.version.to_s
  }

  s.ios.deployment_target = '8.0'

  s.cocoapods_version = '>= 1.5.3'

  # TODO(mikehaney24): Change to static framework after cocoapods 1.6.0 release?
  s.static_framework = false
  s.prefix_header_file = false

  s.source_files = 'GoogleDataLogger/GoogleDataLogger/**/*'
  s.public_header_files = 'GoogleDataLogger/GoogleDataLogger/Classes/Public/*.h'

  s.dependency 'GoogleUtilities/Logger'

  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'GCC_TREAT_WARNINGS_AS_ERRORS' => 'YES',
  }

  # Test specs
  s.test_spec 'Tests' do |test_spec|
    test_spec.source_files = 'GoogleDataLogger/Tests/**/*.{h,m}'
  end
end
