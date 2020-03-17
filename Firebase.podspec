Pod::Spec.new do |s|
  s.name             = 'Firebase'
  s.version          = '6.20.0'
  s.summary          = 'Firebase for iOS (plus community support for macOS and tvOS)'

  s.description      = <<-DESC
Simplify your iOS development, grow your user base, and monetize more effectively with Firebase.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => s.version.to_s
  }

  s.preserve_paths = [
    "CoreOnly/CHANGELOG.md",
    "CoreOnly/NOTICES",
    "CoreOnly/README.md"
  ]
  s.social_media_url = 'https://twitter.com/Firebase'
  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.11'
  s.tvos.deployment_target = '10.0'

  s.cocoapods_version = '>= 1.4.0'

  s.default_subspec = 'Core'

  s.subspec 'Core' do |ss|
    ss.ios.dependency 'FirebaseAnalytics', '6.3.1'
    ss.dependency 'Firebase/CoreOnly'
  end

  s.subspec 'CoreOnly' do |ss|
    ss.dependency 'FirebaseCore', '6.6.4'
    ss.source_files = 'CoreOnly/Sources/Firebase.h'
    ss.preserve_paths = 'CoreOnly/Sources/module.modulemap'
    if ENV['FIREBASE_POD_REPO_FOR_DEV_POD'] then
      ss.user_target_xcconfig = {
        'HEADER_SEARCH_PATHS' => "$(inherited) \"" + ENV['FIREBASE_POD_REPO_FOR_DEV_POD'] + "/CoreOnly/Sources\""
      }
    else
      ss.user_target_xcconfig = {
        'HEADER_SEARCH_PATHS' => "$(inherited) ${PODS_ROOT}/Firebase/CoreOnly/Sources"
      }
    end
    # Standard platforms PLUS watchOS.
    ss.ios.deployment_target = '8.0'
    ss.osx.deployment_target = '10.11'
    ss.tvos.deployment_target = '10.0'
    ss.watchos.deployment_target = '6.0'
  end

  s.subspec 'Analytics' do |ss|
    ss.dependency 'Firebase/Core'
  end

  s.subspec 'ABTesting' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.dependency 'FirebaseABTesting', '~> 3.2.0'
  end

  s.subspec 'AdMob' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.ios.dependency 'Google-Mobile-Ads-SDK', '~> 7.50'
  end

  s.subspec 'Auth' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.dependency 'FirebaseAuth', '~> 6.5.0'
  end

  s.subspec 'Crashlytics' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.dependency 'FirebaseCrashlytics', '~> 4.0.0-beta.5'
  end

  s.subspec 'Database' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.dependency 'FirebaseDatabase', '~> 6.1.4'
  end

  s.subspec 'DynamicLinks' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.ios.dependency 'FirebaseDynamicLinks', '~> 4.0.7'
  end

  s.subspec 'Firestore' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.dependency 'FirebaseFirestore', '~> 1.11.2'
  end

  s.subspec 'Functions' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.dependency 'FirebaseFunctions', '~> 2.5.1'
  end

  s.subspec 'InAppMessaging' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.ios.dependency 'FirebaseInAppMessaging', '~> 0.19.0'
    ss.ios.deployment_target = '9.0'
  end

  s.subspec 'InAppMessagingDisplay' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.ios.dependency 'FirebaseInAppMessagingDisplay', '~> 0.17.0'
    ss.ios.deployment_target = '9.0'
  end

  s.subspec 'Messaging' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.dependency 'FirebaseMessaging', '~> 4.3.0'
    # Standard platforms PLUS watchOS.
    ss.ios.deployment_target = '8.0'
    ss.osx.deployment_target = '10.11'
    ss.tvos.deployment_target = '10.0'
    ss.watchos.deployment_target = '6.0'
  end

  s.subspec 'Performance' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.ios.dependency 'FirebasePerformance', '~> 3.1.10'
  end

  s.subspec 'RemoteConfig' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.dependency 'FirebaseRemoteConfig', '~> 4.4.9'
  end

  s.subspec 'Storage' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.dependency 'FirebaseStorage', '~> 3.6.0'
    # Standard platforms PLUS watchOS.
    ss.ios.deployment_target = '8.0'
    ss.osx.deployment_target = '10.11'
    ss.tvos.deployment_target = '10.0'
    ss.watchos.deployment_target = '6.0'
  end

  s.subspec 'MLCommon' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.ios.dependency 'FirebaseMLCommon', '~> 0.19.0'
  end

  s.subspec 'MLModelInterpreter' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.ios.dependency 'FirebaseMLModelInterpreter', '~> 0.19.0'
    ss.ios.deployment_target = '9.0'
  end

  s.subspec 'MLNLLanguageID' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.ios.dependency 'FirebaseMLNLLanguageID', '~> 0.17.0'
    ss.ios.deployment_target = '9.0'
  end

  s.subspec 'MLNLSmartReply' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.ios.dependency 'FirebaseMLNLSmartReply', '~> 0.17.0'
    ss.ios.deployment_target = '9.0'
  end

  s.subspec 'MLNLTranslate' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.ios.dependency 'FirebaseMLNLTranslate', '~> 0.17.0'
    ss.ios.deployment_target = '9.0'
  end

  s.subspec 'MLNaturalLanguage' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.ios.dependency 'FirebaseMLNaturalLanguage', '~> 0.17.0'
    ss.ios.deployment_target = '9.0'
  end

  s.subspec 'MLVision' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.ios.dependency 'FirebaseMLVision', '~> 0.19.0'
  end

  s.subspec 'MLVisionAutoML' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.ios.dependency 'FirebaseMLVisionAutoML', '~> 0.19.0'
    ss.ios.deployment_target = '9.0'
  end

  s.subspec 'MLVisionBarcodeModel' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.ios.dependency 'FirebaseMLVisionBarcodeModel', '~> 0.19.0'
    ss.ios.deployment_target = '9.0'
  end

  s.subspec 'MLVisionFaceModel' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.ios.dependency 'FirebaseMLVisionFaceModel', '~> 0.19.0'
  end

  s.subspec 'MLVisionLabelModel' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.ios.dependency 'FirebaseMLVisionLabelModel', '~> 0.19.0'
  end

  s.subspec 'MLVisionTextModel' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.ios.dependency 'FirebaseMLVisionTextModel', '~> 0.19.0'
  end

  s.subspec 'MLVisionObjectDetection' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.ios.dependency 'FirebaseMLVisionObjectDetection', '~> 0.19.0'
    ss.ios.deployment_target = '9.0'
  end

end
