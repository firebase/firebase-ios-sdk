Pod::Spec.new do |s|
  s.name             = 'Firebase'
  s.version          = '11.5.0'
  s.summary          = 'Firebase'

  s.description      = <<-DESC
Simplify your app development, grow your user base, and monetize more effectively with Firebase.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache-2.0', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'CocoaPods-' + s.version.to_s
  }

  s.preserve_paths = [
    "CoreOnly/CHANGELOG.md",
    "CoreOnly/NOTICES",
    "CoreOnly/README.md"
  ]
  s.social_media_url = 'https://twitter.com/Firebase'
  s.ios.deployment_target = '12.0'
  s.osx.deployment_target = '10.15'
  s.tvos.deployment_target = '13.0'

  s.cocoapods_version = '>= 1.12.0'

  s.swift_version = '5.9'

  s.default_subspec = 'Core'

  s.subspec 'Core' do |ss|
    ss.ios.deployment_target = '12.0'
    ss.osx.deployment_target = '10.15'
    ss.tvos.deployment_target = '13.0'
    ss.ios.dependency 'FirebaseAnalytics', '~> 11.5.0'
    ss.osx.dependency 'FirebaseAnalytics', '~> 11.5.0'
    ss.tvos.dependency 'FirebaseAnalytics', '~> 11.5.0'
    ss.dependency 'Firebase/CoreOnly'
  end

  s.subspec 'CoreOnly' do |ss|
    ss.dependency 'FirebaseCore', '11.5.0'
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
    ss.ios.deployment_target = '12.0'
    ss.osx.deployment_target = '10.15'
    ss.tvos.deployment_target = '13.0'
    ss.watchos.deployment_target = '7.0'
  end

  s.subspec 'Analytics' do |ss|
    ss.ios.deployment_target = '12.0'
    ss.osx.deployment_target = '10.15'
    ss.tvos.deployment_target = '13.0'
    ss.dependency 'Firebase/Core'
  end

  s.subspec 'AnalyticsWithAdIdSupport' do |ss|
    ss.ios.deployment_target = '12.0'
    ss.osx.deployment_target = '10.15'
    ss.tvos.deployment_target = '13.0'
    ss.dependency 'Firebase/Core'
  end

  s.subspec 'AnalyticsWithoutAdIdSupport' do |ss|
    ss.ios.deployment_target = '12.0'
    ss.osx.deployment_target = '10.15'
    ss.tvos.deployment_target = '13.0'
    ss.dependency 'FirebaseAnalytics/WithoutAdIdSupport', '~> 11.5.0'
    ss.dependency 'Firebase/CoreOnly'
  end

  s.subspec 'ABTesting' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.dependency 'FirebaseABTesting', '~> 11.5.0'
    # Standard platforms PLUS watchOS.
    ss.ios.deployment_target = '13.0'
    ss.osx.deployment_target = '10.15'
    ss.tvos.deployment_target = '13.0'
    ss.watchos.deployment_target = '7.0'
  end

  s.subspec 'AppDistribution' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.ios.dependency 'FirebaseAppDistribution', '~> 11.5.0-beta'
    ss.ios.deployment_target = '13.0'
  end

  s.subspec 'AppCheck' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.dependency 'FirebaseAppCheck', '~> 11.5.0'
    ss.ios.deployment_target = '13.0'
    ss.osx.deployment_target = '10.15'
    ss.tvos.deployment_target = '13.0'
    ss.watchos.deployment_target = '7.0'
  end

  s.subspec 'Auth' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.dependency 'FirebaseAuth', '~> 11.5.0'
    # Standard platforms PLUS watchOS.
    ss.ios.deployment_target = '13.0'
    ss.osx.deployment_target = '10.15'
    ss.tvos.deployment_target = '13.0'
    ss.watchos.deployment_target = '7.0'
  end

  s.subspec 'Crashlytics' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.dependency 'FirebaseCrashlytics', '~> 11.5.0'
    # Standard platforms PLUS watchOS.
    ss.ios.deployment_target = '12.0'
    ss.osx.deployment_target = '10.15'
    ss.tvos.deployment_target = '13.0'
    ss.watchos.deployment_target = '7.0'
  end

  s.subspec 'Database' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.dependency 'FirebaseDatabase', '~> 11.5.0'
    # Standard platforms PLUS watchOS 7.
    ss.ios.deployment_target = '13.0'
    ss.osx.deployment_target = '10.15'
    ss.tvos.deployment_target = '13.0'
    ss.watchos.deployment_target = '7.0'
  end

  s.subspec 'DynamicLinks' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.ios.dependency 'FirebaseDynamicLinks', '~> 11.5.0'
    ss.ios.deployment_target = '13.0'
  end

  s.subspec 'Firestore' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.dependency 'FirebaseFirestore', '~> 11.5.0'
    ss.ios.deployment_target = '13.0'
    ss.osx.deployment_target = '10.15'
    ss.tvos.deployment_target = '13.0'
  end

  s.subspec 'Functions' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.dependency 'FirebaseFunctions', '~> 11.5.0'
    # Standard platforms PLUS watchOS.
    ss.ios.deployment_target = '13.0'
    ss.osx.deployment_target = '10.15'
    ss.tvos.deployment_target = '13.0'
    ss.watchos.deployment_target = '7.0'
  end

  s.subspec 'InAppMessaging' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.ios.dependency 'FirebaseInAppMessaging', '~> 11.5.0-beta'
    ss.tvos.dependency 'FirebaseInAppMessaging', '~> 11.5.0-beta'
    ss.ios.deployment_target = '13.0'
    ss.tvos.deployment_target = '13.0'
  end

  s.subspec 'Installations' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.dependency 'FirebaseInstallations', '~> 11.5.0'
  end

  s.subspec 'Messaging' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.dependency 'FirebaseMessaging', '~> 11.5.0'
    # Standard platforms PLUS watchOS.
    ss.ios.deployment_target = '13.0'
    ss.osx.deployment_target = '10.15'
    ss.tvos.deployment_target = '13.0'
    ss.watchos.deployment_target = '7.0'
  end

  s.subspec 'MLModelDownloader' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.dependency 'FirebaseMLModelDownloader', '~> 11.5.0-beta'
    # Standard platforms PLUS watchOS.
    ss.ios.deployment_target = '13.0'
    ss.osx.deployment_target = '10.15'
    ss.tvos.deployment_target = '13.0'
    ss.watchos.deployment_target = '7.0'
  end

  s.subspec 'Performance' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.ios.dependency 'FirebasePerformance', '~> 11.5.0'
    ss.tvos.dependency 'FirebasePerformance', '~> 11.5.0'
    ss.ios.deployment_target = '13.0'
    ss.tvos.deployment_target = '13.0'
  end

  s.subspec 'RemoteConfig' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.dependency 'FirebaseRemoteConfig', '~> 11.5.0'
    # Standard platforms PLUS watchOS.
    ss.ios.deployment_target = '13.0'
    ss.osx.deployment_target = '10.15'
    ss.tvos.deployment_target = '13.0'
    ss.watchos.deployment_target = '7.0'
  end

  s.subspec 'Storage' do |ss|
    ss.dependency 'Firebase/CoreOnly'
    ss.dependency 'FirebaseStorage', '~> 11.5.0'
    # Standard platforms PLUS watchOS.
    ss.ios.deployment_target = '13.0'
    ss.osx.deployment_target = '10.15'
    ss.tvos.deployment_target = '13.0'
    ss.watchos.deployment_target = '7.0'
  end

end
