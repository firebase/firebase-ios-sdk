Pod::Spec.new do |s|
  s.name             = 'FirebaseVertexAI'
  s.version          = '0.1.0'
  s.summary          = 'Firebase VertexAI'

  s.description      = <<-DESC
  Placeholder podspec for docsgen only.
                        DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache-2.0', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'vertexai-preview-0.1.0'
  }

  s.social_media_url = 'https://twitter.com/Firebase'

  ios_deployment_target = '15.0'
  osx_deployment_target = '10.14'

  s.ios.deployment_target = ios_deployment_target
  s.osx.deployment_target = osx_deployment_target

  s.cocoapods_version = '>= 1.12.0'
  s.prefix_header_file = false

  s.source_files = [
    'FirebaseVertexAI/Sources/**/*.swift',
    'FirebaseCore/Extension/*.h',
    'FirebaseAuth/Interop/*.h',
  ]

  s.swift_version = '5.3'

  s.framework = 'Foundation'
  s.ios.framework = 'UIKit'
  s.osx.framework = 'AppKit'
  s.tvos.framework = 'UIKit'
  s.watchos.framework = 'WatchKit'

  s.dependency 'FirebaseCore', '~> 10.0'
  s.dependency 'FirebaseCoreExtension'
  s.dependency 'FirebaseAppCheckInterop', '~> 10.17'

  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}"',
    'OTHER_CFLAGS' => '-fno-autolink'
  }
end
