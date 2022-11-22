Pod::Spec.new do |s|
  s.name             = 'FirebaseAuthExchange'
  s.version          = '10.2.0'
  s.summary          = 'Apple platform client for Firebase Authentication Exchange'

  s.description      = <<-DESC
Firebase Authentication Exchange allows you to bring your own Customer Identity Access Management (CIAM) solution to the Firebase ecosystem.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache-2.0', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'CocoaPods-' + s.version.to_s
  }

  s.social_media_url = 'https://twitter.com/Firebase'

  ios_deployment_target = '11.0'
  osx_deployment_target = '10.13'
  tvos_deployment_target = '12.0'
  watchos_deployment_target = '6.0'

  s.swift_version = '5.6'

  s.ios.deployment_target = ios_deployment_target
  s.osx.deployment_target = osx_deployment_target
  s.tvos.deployment_target = tvos_deployment_target
  s.watchos.deployment_target = watchos_deployment_target

  s.cocoapods_version = '>= 1.4.0'
  s.prefix_header_file = false

  s.source_files = [
    'FirebaseAuthExchange/Interop/*.swift',
    'FirebaseAuthExchange/Sources/**/*.swift',
  ]

  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}"'
  }

  s.dependency 'FirebaseCore', '~> 10.0'
  s.dependency 'FirebaseCoreExtension', '~> 10.0'
end
