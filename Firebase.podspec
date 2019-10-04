Pod::Spec.new do |s|
  s.name             = 'Firebase'
  s.version          = '6.9.901-test'
  s.summary          = 'Firebase for iOS (plus community support for macOS and tvOS)'

  s.description      = <<-DESC
Simplify your iOS development, grow your user base, and monetize more effectively with Firebase.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'Firebase-' + s.version.to_s
  }

  s.preserve_paths = [
    "Firebase/Firebase/.cocoapods.yml",
    "Firebase/Firebase/CHANGELOG.md",
    "Firebase/Firebase/NOTICES",
    "Firebase/Firebase/README.md"
  ]
  s.social_media_url = 'https://twitter.com/Firebase'
  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.11'
  s.tvos.deployment_target = '10.0'

  s.cocoapods_version = '>= 1.4.0'

  s.default_subspec = 'Core'

  s.subspec 'Core' do |ss|
    ss.ios.dependency 'FirebaseAnalytics', '6.1.2'
    ss.dependency 'Firebase/CoreOnly'
  end

  s.subspec 'CoreOnly' do |ss|
    ss.dependency 'FirebaseCore', '6.3.0'
    ss.source_files = 'Firebase/Firebase/Sources/Firebase.h'
    ss.preserve_paths = 'Firebase/Firebase/Sources/module.modulemap'
    ss.user_target_xcconfig = {
      'HEADER_SEARCH_PATHS' => "$(inherited) ${PODS_ROOT}/Firebase/Firebase/Firebase/Sources"
    }
  end

  s.subspec 'Analytics' do |ss|
    ss.dependency 'Firebase/Core'
    ss.ios.deployment_target = '8.0'
  end

  s.subspec 'MLCommon' do |ss|
    ss.dependency 'FirebaseMLCommon', '~> 0.18.0'
    ss.ios.deployment_target = '8.0'
  end

  s.subspec 'MLModelInterpreter' do |ss|
    ss.ios.dependency 'FirebaseMLModelInterpreter', '~> 0.18.0'
    ss.ios.deployment_target = '9.0'
    ss.osx.dependency 'FirebaseCore'
    ss.tvos.dependency 'FirebaseCore'
  end

  s.subspec 'MLNLLanguageID' do |ss|
    ss.ios.dependency 'FirebaseMLNLLanguageID', '~> 0.16.4'
    ss.ios.deployment_target = '9.0'
    ss.osx.dependency 'FirebaseCore'
    ss.tvos.dependency 'FirebaseCore'
  end

  s.subspec 'MLNLSmartReply' do |ss|
    ss.ios.dependency 'FirebaseMLNLSmartReply', '~> 0.16.4'
    ss.ios.deployment_target = '9.0'
    ss.osx.dependency 'FirebaseCore'
    ss.tvos.dependency 'FirebaseCore'
  end

  s.subspec 'MLNLTranslate' do |ss|
    ss.ios.dependency 'FirebaseMLNLTranslate', '~> 0.16.4'
    ss.ios.deployment_target = '9.0'
    ss.osx.dependency 'FirebaseCore'
    ss.tvos.dependency 'FirebaseCore'
  end

  s.subspec 'MLNaturalLanguage' do |ss|
    ss.ios.dependency 'FirebaseMLNaturalLanguage', '~> 0.16.4'
    ss.ios.deployment_target = '9.0'
    ss.osx.dependency 'FirebaseCore'
    ss.tvos.dependency 'FirebaseCore'
  end



end
