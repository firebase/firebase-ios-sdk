Pod::Spec.new do |s|
  s.name             = 'FirebaseCore'
  s.version          = '4.0.13'
  s.summary          = 'Firebase Core for iOS'

  s.description      = <<-DESC
Firebase Core includes FIRApp and FIROptions which provide central configuration for other Firebase services.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => s.version.to_s
  }
  s.social_media_url = 'https://twitter.com/Firebase'
  s.ios.deployment_target = '7.0'
  s.osx.deployment_target = '10.10'
  s.tvos.deployment_target = '10.0'

  s.cocoapods_version = '>= 1.4.0.beta.2'
  s.static_framework = true
  s.prefix_header_file = false

  s.source_files = 'Firebase/Core/**/*.[mh]'
  s.public_header_files = 'Firebase/Core/Public/*.h', 'Firebase/Core/Private/*.h'
  s.private_header_files = 'Firebase/Core/Private/*.h'
  s.frameworks = [
    'Foundation',
    'SystemConfiguration'
  ]
  s.dependency 'GoogleToolboxForMac/NSData+zlib', '~> 2.1'
  s.pod_target_xcconfig = {
    'OTHER_CFLAGS' => '-fno-autolink ' +
      '-DFIRCore_VERSION=' + s.version.to_s + ' -DFirebase_VERSION=4.8.0'
  }
end
