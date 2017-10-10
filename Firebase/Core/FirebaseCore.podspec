Pod::Spec.new do |s|
  s.name             = 'FirebaseCore'
  s.version          = '4.0.9'
  s.summary          = 'Firebase Open Source Libraries for iOS.'

  s.description      = <<-DESC
Firebase Core includes FIRApp and FIROptions which provide central configuration for other Firebase services.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache', :file => '../../LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = { :git => 'https://github.com/firebase/firebase-ios-sdk.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/Firebase'
  s.ios.deployment_target = '7.0'
  s.osx.deployment_target = '10.10'

  s.cocoapods_version = '>= 1.4.0.beta.1'
  s.static_framework = true
  s.prefix_header_file = false

  s.source_files = '**/*.[mh]'
  s.public_header_files = 'Public/*.h', 'Private/*.h'
  s.private_header_files = 'Private/*.h'
  s.ios.vendored_frameworks = [
    "Frameworks/FirebaseCoreDiagnostics.framework",
    "Frameworks/FirebaseNanoPB.framework"
  ]
  s.framework = 'SystemConfiguration'
  s.dependency 'GoogleToolboxForMac/NSData+zlib', '~> 2.1'
end
