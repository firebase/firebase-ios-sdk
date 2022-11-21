Pod::Spec.new do |s|
  s.name             = 'FirebaseAuthExchangeInterop'
  s.version          = '10.2.0'
  s.summary          = 'Interfaces that allow other Firebase SDKs to use Auth Exchange functionality.'

  s.description      = <<-DESC
  Not for public use.
  A set of protocols that other Firebase SDKs can use to interoperate with FirebaseAuthExchange in a safe
  and reliable manner.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache-2.0', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  # NOTE that these should not be used externally, this is for Firebase pods to depend on each
  # other.
  # TODO(rosalyntan): Change this to point to private branch while under development?
  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'CocoaPods-' + s.version.to_s
  }
  s.social_media_url = 'https://twitter.com/Firebase'
  s.ios.deployment_target = '11.0'
  s.osx.deployment_target = '10.13'
  s.tvos.deployment_target = '12.0'
  s.watchos.deployment_target = '6.0'

  s.source_files = 'FirebaseAuthExchange/Interop/*.swift'
end
