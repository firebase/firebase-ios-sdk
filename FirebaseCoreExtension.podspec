Pod::Spec.new do |s|
    s.name             = 'FirebaseCoreExtension'
    s.version          = '9.6.0'
    s.summary          = 'Extended FirebaseCore APIs for Firebase product SDKs'

    s.description      = <<-DESC
    Not for public use.
    Common FirebaseCore APIs for use in Firebase product SDKs.
                         DESC

    s.homepage         = 'https://firebase.google.com'
    s.license          = { :type => 'Apache-2.0', :file => 'LICENSE' }
    s.authors          = 'Google, Inc.'

    s.source           = {
      :git => 'https://github.com/firebase/firebase-ios-sdk.git',
      :tag => 'CocoaPods-' + s.version.to_s
    }
    s.social_media_url = 'https://twitter.com/Firebase'

    s.swift_version = '5.3'

    s.ios.deployment_target = '9.0'
    s.osx.deployment_target = '10.12'
    s.tvos.deployment_target = '10.0'
    s.watchos.deployment_target = '6.0'

    s.source_files = 'FirebaseCore/Extension/*.[hm]'
    s.public_header_files = 'FirebaseCore/Extension/*.h'

    s.dependency 'FirebaseCore', '~> 9.0'
  end
