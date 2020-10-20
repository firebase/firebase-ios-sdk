Pod::Spec.new do |s|
  s.name             = 'FirebaseAppCheckInterop'
  s.version          = '7.0.0-beta'
  s.summary          = 'Interfaces that allow other Firebase SDKs to use Firebase App Check SDK.'

  s.description      = <<-DESC
  Interfaces that allow other Firebase SDKs to use Firebase App Check SDK.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'AppCheckInterop-' + s.version.to_s
  }
  s.social_media_url = 'https://twitter.com/Firebase'
  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.11'
  s.tvos.deployment_target = '10.0'
  s.watchos.deployment_target = '6.0'

  s.cocoapods_version = '>= 1.4.0'
  s.static_framework = true
  s.prefix_header_file = false

  base_dir = "Interop/AppCheck/"
  s.source_files = base_dir + '**/*.h'
  s.public_header_files = base_dir + 'Public/*.h'
end
