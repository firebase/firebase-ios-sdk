Pod::Spec.new do |s|
  s.name             = 'FirebaseRemoteConfigInterop'
  s.version          = '11.5.0'
  s.summary          = 'Interfaces that allow other Firebase SDKs to use Remote Config functionality.'

  s.description      = <<-DESC
  Not for public use.
  A set of protocols that other Firebase SDKs can use to interoperate with FirebaseRemoetConfig in a safe
  and reliable manner.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache-2.0', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  # NOTE that these should not be used externally, this is for Firebase pods to depend on each
  # other.
  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'CocoaPods-' + s.version.to_s
  }

  s.swift_version = '5.9'
  s.cocoapods_version = '>= 1.12.0'
  s.prefix_header_file = false

  s.social_media_url = 'https://twitter.com/Firebase'

  # The ios deployment target must support Crashlytics.
  s.ios.deployment_target = '12.0'
  s.osx.deployment_target = '10.15'
  s.tvos.deployment_target = '13.0'
  s.watchos.deployment_target = '7.0'

  s.source_files = 'FirebaseRemoteConfig/Interop/*.swift'
end
