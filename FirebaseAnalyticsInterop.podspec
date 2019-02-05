Pod::Spec.new do |s|
  s.name             = 'FirebaseAnalyticsInterop'
  s.version          = '1.2.0'
  s.summary          = 'Interfaces that allow other Firebase SDKs to use Analytics functionality.'

  s.description      = <<-DESC
  Not for public use.

  A set of protocols that other Firebase SDKs can use to interoperate with FirebaseAnalytics in a
  safe and reliable manner.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  # NOTE that these should not be used externally, this is for Firebase pods to depend on each
  # other.
  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'AnalyticsInterop-' + s.version.to_s
  }
  s.social_media_url = 'https://twitter.com/Firebase'
  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.10'
  s.tvos.deployment_target = '10.0'
  s.source_files = 'Interop/Analytics/**/*.h'
  s.public_header_files = 'Interop/Analytics/Public/*.h'
end
