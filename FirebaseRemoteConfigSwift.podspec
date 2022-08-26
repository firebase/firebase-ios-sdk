Pod::Spec.new do |s|
  s.name                    = 'FirebaseRemoteConfigSwift'
  s.version                 = '9.6.0'
  s.summary                 = 'Swift Extensions for Firebase Remote Config'

  s.description      = <<-DESC
Firebase Remote Config is a cloud service that lets you change the
appearance and behavior of your app without requiring users to download an
app update.
                       DESC


  s.homepage                = 'https://developers.google.com/'
  s.license                 = { :type => 'Apache-2.0', :file => 'LICENSE' }
  s.authors                 = 'Google, Inc.'

  s.source                  = {
    :git => 'https://github.com/Firebase/firebase-ios-sdk.git',
    :tag => 'CocoaPods-' + s.version.to_s
  }

  s.swift_version           = '5.3'

  ios_deployment_target = '10.0'
  osx_deployment_target = '10.12'
  tvos_deployment_target = '10.0'
  watchos_deployment_target = '6.0'

  s.ios.deployment_target = ios_deployment_target
  s.osx.deployment_target = osx_deployment_target
  s.tvos.deployment_target = tvos_deployment_target
  s.watchos.deployment_target = watchos_deployment_target

  s.cocoapods_version       = '>= 1.4.0'
  s.prefix_header_file      = false

  s.source_files = [
    'FirebaseRemoteConfigSwift/Sources/*.swift',
  ]

  s.dependency 'FirebaseRemoteConfig', '~> 9.0'
  s.dependency 'FirebaseSharedSwift', '~> 9.0'

  # Run Swift API tests on a real backend.
  s.test_spec 'swift-api-tests' do |swift_api|
    swift_api.scheme = { :code_coverage => true }
    swift_api.platforms = {
      :ios => ios_deployment_target,
      :osx => osx_deployment_target,
      :tvos => tvos_deployment_target
    }
    swift_api.source_files = ['FirebaseRemoteConfigSwift/Tests/SwiftAPI/*.swift',
                              'FirebaseRemoteConfigSwift/Tests/FakeUtils/*.swift',
                              'FirebaseRemoteConfigSwift/Tests/ObjC/*.[hm]',
                             ]
    swift_api.resources = 'FirebaseRemoteConfigSwift/Tests/Defaults-testInfo.plist'
    swift_api.requires_app_host = true
    swift_api.pod_target_xcconfig = {
      'SWIFT_OBJC_BRIDGING_HEADER' => '$(PODS_TARGET_SRCROOT)/FirebaseRemoteConfigSwift/Tests/ObjC/Bridging-Header.h',
      'OTHER_SWIFT_FLAGS' => '$(inherited) -D USE_REAL_CONSOLE',
      'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}"'
    }
    swift_api.dependency 'OCMock'
  end

  # Run Swift API tests and tests requiring console changes on a Fake Console.
  s.test_spec 'fake-console-tests' do |fake_console|
    fake_console.scheme = { :code_coverage => true }
    fake_console.platforms = {
      :ios => ios_deployment_target,
      :osx => osx_deployment_target,
      :tvos => tvos_deployment_target
    }
    fake_console.source_files = ['FirebaseRemoteConfigSwift/Tests/SwiftAPI/*.swift',
                                 'FirebaseRemoteConfigSwift/Tests/FakeUtils/*.swift',
                                 'FirebaseRemoteConfigSwift/Tests/FakeConsole/*.swift',
                                 'FirebaseRemoteConfigSwift/Tests/ObjC/*.[hm]',
                                ]
    fake_console.resources = 'FirebaseRemoteConfigSwift/Tests/Defaults-testInfo.plist'
    fake_console.requires_app_host = true
    fake_console.pod_target_xcconfig = {
      'SWIFT_OBJC_BRIDGING_HEADER' => '$(PODS_TARGET_SRCROOT)/FirebaseRemoteConfigSwift/Tests/ObjC/Bridging-Header.h',
      'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}"'
    }
    fake_console.dependency 'OCMock'
  end
end
