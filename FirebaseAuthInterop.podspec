Pod::Spec.new do |s|
  s.name             = 'FirebaseAuthInterop'
  s.version          = '9.6.0'
  s.summary          = 'Interfaces that allow other Firebase SDKs to use Auth functionality.'

  s.description      = <<-DESC
  Not for public use.
  A set of protocols that other Firebase SDKs can use to interoperate with FirebaseAuth in a safe
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
  s.social_media_url = 'https://twitter.com/Firebase'
  s.ios.deployment_target = '10.0'
  s.osx.deployment_target = '10.12'
  s.tvos.deployment_target = '10.0'
  s.watchos.deployment_target = '6.0'

  s.source_files = 'FirebaseAuth/Interop/*.[hm]'
  s.public_header_files = 'FirebaseAuth/Interop/*.h'
end
