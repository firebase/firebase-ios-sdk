Pod::Spec.new do |s|
  s.name             = 'FirebaseCoreInternal'
  s.version          = '9.0.0'
  s.summary          = 'APIs only for Firebase internal usage'

  s.description      = <<-DESC
  Not for public use.
  Common APIs for internal Firebase usage.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'CocoaPods-' + s.version.to_s
  }
  s.social_media_url = 'https://twitter.com/Firebase'
  s.ios.deployment_target = '9.0'
  s.osx.deployment_target = '10.12'
  s.tvos.deployment_target = '10.0'
  s.watchos.deployment_target = '6.0'

  s.source_files = 'FirebaseCore/Internal/*.[hm]'
  s.public_header_files = 'FirebaseCore/Internal/*.h'

  s.dependency 'FirebaseCore', '~> 8.12'
end