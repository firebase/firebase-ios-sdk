Pod::Spec.new do |s|
  s.name             = 'FirebaseAppCheckInterop'
  s.version          = '11.5.0'
  s.summary          = 'Interfaces that allow other Firebase SDKs to use AppCheck functionality.'

  s.description      = <<-DESC
  Not for public use.
  A set of protocols that other Firebase SDKs can use to interoperate with FirebaseAppCheck in a safe
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

  ios_deployment_target = '13.0'
  osx_deployment_target = '10.15'
  tvos_deployment_target = '13.0'
  watchos_deployment_target = '7.0'

  s.ios.deployment_target = ios_deployment_target
  s.osx.deployment_target = osx_deployment_target
  s.tvos.deployment_target = tvos_deployment_target
  s.watchos.deployment_target = watchos_deployment_target

  s.source_files = 'FirebaseAppCheck/Interop/**/*.[hm]'
  s.public_header_files = 'FirebaseAppCheck/Interop/Public/FirebaseAppCheckInterop/*.h'

  s.test_spec 'objc-unit' do |unit_tests|
    unit_tests.platforms = {
      :ios => ios_deployment_target,
      :osx => osx_deployment_target,
      :tvos => tvos_deployment_target
    }
    unit_tests.source_files = [
      'FirebaseAppCheck/Tests/Interop/ObjC/**/*.[hm]',
    ]
  end

  s.test_spec 'swift-unit' do |swift_unit_tests|
    swift_unit_tests.platforms = {
      :ios => ios_deployment_target,
      :osx => osx_deployment_target,
      :tvos => tvos_deployment_target
    }
    swift_unit_tests.source_files = [
      'FirebaseAppCheck/Tests/Interop/Swift/**/*.swift',
    ]
  end
end
