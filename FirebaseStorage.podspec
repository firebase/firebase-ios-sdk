Pod::Spec.new do |s|
  s.name             = 'FirebaseStorage'
  s.version          = '3.0.0'
  s.summary          = 'Firebase Storage for iOS (plus experimental support for macOS and tvOS)'

  s.description      = <<-DESC
Firebase Storage provides robust, secure file uploads and downloads from Firebase SDKs, powered by Google Cloud Storage.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'Storage-' + s.version.to_s
  }
  s.social_media_url = 'https://twitter.com/Firebase'
  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.10'
  s.tvos.deployment_target = '10.0'

  s.cocoapods_version = '>= 1.4.0'
  s.static_framework = true
  s.prefix_header_file = false

  s.source_files = 'Firebase/Storage/**/*.[mh]'
  s.public_header_files = 'Firebase/Storage/Public/*.h'
  s.ios.framework = 'MobileCoreServices'
  s.osx.framework = 'CoreServices'

  s.dependency 'FirebaseCore', '~> 5.0'
  s.dependency 'GTMSessionFetcher/Core', '~> 1.1'
  s.pod_target_xcconfig = {
    'GCC_PREPROCESSOR_DEFINITIONS' =>
      'FIRStorage_VERSION=' + s.version.to_s }
end
