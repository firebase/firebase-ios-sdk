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

  s.cocoapods_version = '>= 1.4.0'
  s.static_framework = true
  s.prefix_header_file = false

  s.source_files = 'GoogleDataLogger/GoogleDataLogger/**/*'
  s.public_header_files = 'GoogleDataLogger/GoogleDataLogger/Public/*.h'

  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99'
  }
end
